-- Reloading and checking the ammo (client). R (B on a controller) asks the server to reload, then plays the game's
-- reload. G checks the ammo. R and B do nothing in a vehicle: there a seat's own reloads are the only ones
-- (client/vehicle.lua).
--
-- Firing stops the moment a reload is asked for and comes back when it is over (GunnyStartReload; aiming stays), since
-- the server swaps the magazine as it answers and a shot in between would come off the new magazine. A pump's
-- shell-at-a-time reload lets go as its animation starts: firing is how the player stops it partway.
--
-- Two latches: isReloading is a reload asked for and not finished (no second R); GunnyReloading is its animation, from
-- the server's yes to the end: shots are not counted and the ammo sync holds off. A count sent before the swap carries the
-- old count version and is ignored (GunnyCountChanged).
--
-- From the press to the end (GunnyReloadUnderWay), an ordinary holster and a draw are refused (a death or a block still
-- puts the gun away at once), and R does nothing while the gun is going away (GunnyPuttingAway).

local isReloading = false
GunnyReloading = false

--- From the press (GunnyStartReload) until the reload's thread ends: the server's answer, then the animation.
local underWay = false

--- Is a reload under way, asked for or playing? (client/weapons.lua refuses an ordinary holster and a draw meanwhile.)
---@return boolean
function GunnyReloadUnderWay()
    return underWay or GunnyReloading
end

-- Firing held off during a reload (whip's control blocks: /whipcontrols shows it): on foot, and from a seat. Aiming is
-- not held: a reload can be made aimed.
local FIRE_BLOCK = 'gunReloading'
local FIRE_CONTROLS = { 24, 257, 69, 70, 92 }   -- attack and attack 2; a driver's two; a passenger's
local fireHeld = false

--- Held or let go, only when that changes.
local function holdFire(on)
    if on == fireHeld then return end
    fireHeld = on
    local ok, why
    if on then ok, why = Whip.call('BlockControls', FIRE_BLOCK, { controls = FIRE_CONTROLS })
    else ok, why = Whip.call('UnblockControls', FIRE_BLOCK) end
    if ok ~= true then GunnyDebugPrint('Reload: the fire keys could not be', on and 'held' or 'let go', why) end
end

--- Start a reload: R, B on a controller, a seat's automatic reload. Firing stops here, where it is asked for, before
--- the reload's own thread runs: no shot from after the press can reach the server after the reload's ask. The reload
--- runs in its own thread, as it waits for the server (and a wait inside a pcall run straight from a command handler
--- fails silently: whip's rule).
function GunnyStartReload()
    if isReloading or underWay then return end   -- the one under way holds the keys
    if GunnyPuttingAway() then return end         -- the gun is going away: it is not reloaded on its way out
    underWay = true
    holdFire(true)
    CreateThread(GunnyReload)
end

--- R and B are the player's own reload, and not from a seat (the top of this file says why): refused there, silently.
--- On the way into a seat (not in it yet) they still reload; a reload started on foot plays out in the seat.
---@return boolean refused
local function seatRefusesReload()
    return IsPedInAnyVehicle(PlayerPedId(), false)
end

RegisterCommand('+gunny_reload', function()
    if not CurrentWeapon then return end
    -- Guns only, silently: with a melee weapon R is the game's own light attack.
    if not Config.IsFirearm(CurrentWeapon.config) then return end
    if isReloading then return end
    -- Not while a bar, a screen or anything else owns the keys (the furnisher uses R).
    if Whip.call('IsGameInputFree') ~= true then return end
    if seatRefusesReload() then return end

    GunnyStartReload()
end, false)
RegisterCommand('-gunny_reload', function() end, false)
RegisterKeyMapping('+gunny_reload', 'Reload Weapon', 'keyboard', 'r')

--- In a seat a reload takes at least the weapon's reloadTime: the game may play no animation there.
local function seatedMinMs(ped)
    if not IsPedInAnyVehicle(ped, false) then return nil end
    local cfg = CurrentWeapon and CurrentWeapon.config
    return cfg and cfg.reloadTime or 1500
end

--- The reload is over without the gun: it went while the server answered or the animation played (death, a forced
--- holster, a resource restart). Both latches go, or no reload, shot or draw would ever happen again.
local function reloadStoodDown()
    isReloading = false
    GunnyReloading = false
    GunnyDebugCounts.lastReloadAt = GetGameTimer()
end

--- The server said yes: the animation's latch goes on, and the gun takes the answer's count and the count's version
--- (GunnyCountChanged on the server). The count now, not at the animation's end: a death mid-animation holsters with
--- CurrentWeapon.ammo. The ped's own ammo is set when the animation ends (GunnyAmmo.set).
local function takeReloadAnswer(result)
    GunnyReloading = true
    CurrentWeapon.ammo = math.max(0, math.floor(tonumber(result.ammo) or 0))
    CurrentWeapon.countVersion = tonumber(result.countVersion) or CurrentWeapon.countVersion
end

--- A gun with no magazine: the rounds it has room for, all at once.
local function maglessReload()
    local gun = CurrentWeapon

    -- The server first; the animation only once it has said yes.
    local ok, result = GunnyCallback('whip_gunny:performMaglessReload', GunnySlot(gun.slot, gun.pocket))
    if not ok then
        GunnyNotify(type(result) == 'string' and result or 'Cannot reload', 'error')
        isReloading = false
        return
    end
    if CurrentWeapon ~= gun then reloadStoodDown() return end
    local loaded = result.loaded

    local ped = PlayerPedId()
    takeReloadAnswer(result)

    GunnyAmmo.playReloadAnimation({ waitForEnd = true, minMs = seatedMinMs(ped) })

    -- CurrentWeapon may have been cleared during the yield (death, holster, resource restart)
    if CurrentWeapon ~= gun then reloadStoodDown() return end

    GunnyAmmo.endAnimation(ped)

    GunnyReloading = false

    GunnyDebugCounts.lastReloadAt = GetGameTimer()

    GunnyDebugPrint('Magless reload complete -', CurrentWeapon.ammo, 'rounds (loaded', loaded, ')')

    isReloading = false
end

-- A shell at a time (Config `loopedReload`: the pump, on foot). The server takes nothing yet: it says how
-- many may go in, and hears how many did in the frame the reload ends (GunnyLoopedReloadTick). So the
-- latch is on only while the animation plays, and a shot fired while the server answers is counted.
local loopedEnd = nil    -- how the last one ended: { timedOut }
local loopedWait = nil   -- the promise shellByShellReload waits on while one plays

--- The shell-at-a-time reload is over: it ended, failed, or the gun went (GunnyAfterHolster, below).
local function endLoopedWait()
    local p = loopedWait
    loopedWait = nil
    if p then p:resolve(true) end
end

local function shellByShellReload(capacity)
    local gun = CurrentWeapon
    local ok, room = GunnyCallback('whip_gunny:beginLoopedReload', GunnySlot(gun.slot, gun.pocket))
    if not ok then
        GunnyNotify(type(room) == 'string' and room or 'Cannot reload', 'error')
        isReloading = false
        return
    end
    -- Put away, or another gun drawn, while the server answered; shots taken meanwhile make more room,
    -- never more than the server allowed.
    if CurrentWeapon ~= gun then isReloading = false; return end
    room = math.min(math.floor(tonumber(room) or 0), capacity - GunnyAmmo.count())
    if room <= 0 then isReloading = false; return end

    local ped = PlayerPedId()
    -- The draw's animation ended first (it can take a moment): waited for here, before the wait below exists, or the
    -- tick would see no reload playing yet and end that wait at once.
    GunnyEndDrawAnim(ped)
    if CurrentWeapon ~= gun then isReloading = false; return end
    holdFire(false)   -- from here a shot stops the reload, and is counted (GunnyLoopedReloadTick)
    GunnyReloading = true
    loopedEnd = nil
    loopedWait = promise.new()
    local waiting = loopedWait
    GunnyAmmo.startLoopedReload(room)
    Citizen.Await(waiting)

    GunnyDebugCounts.lastReloadAt = GetGameTimer()
    if CurrentWeapon ~= gun then
        -- Put away mid-reload (dying): the gun keeps what it had, and nothing is taken.
        GunnyAmmo.dropLoopedReload()
        GunnyReloading = false
        isReloading = false
        return
    end
    -- Ended or stopped, the ped is left as it is: clearing its tasks would cut the aim or the run it was
    -- stopped for. Only one stuck past the time out is ended.
    if loopedEnd and loopedEnd.timedOut then GunnyAmmo.endAnimation(ped) end
    GunnyDebugPrint('Looped reload ended -', GunnyAmmo.count(), 'rounds')
    isReloading = false
end

--- Every frame, from the shooting tick before it counts a shot: a shell-at-a-time reload ends in the frame
--- it ends, so the server hears what went in before the shot that stopped it, and that shot is counted.
function GunnyLoopedReloadTick(ped, now)
    if not GunnyAmmo.loopedReloading() then
        -- Ended without a word (the gun in hand changed under it): whoever waits is told all the same.
        if loopedWait then endLoopedWait() end
        return
    end
    -- Its own pcall: a failure here must not leave the latch on, which would stop shots being counted.
    local ok, loaded, _, timedOut = pcall(GunnyAmmo.loopedReloadFrame, ped, now)
    if not ok then
        print(('[GUNNY] shell-at-a-time reload failed: %s'):format(tostring(loaded)))
        GunnyAmmo.dropLoopedReload()
        GunnyAmmo.set(GunnyAmmo.count())   -- the reserve goes; the gun keeps what it had
        GunnyReloading = false
        endLoopedWait()
        return
    end
    if not loaded then return end
    loopedEnd = { timedOut = timedOut }
    TriggerServerEvent('whip_gunny:server:loopedReloadEnded', loaded)
    GunnyReloading = false
    endLoopedWait()
end

-- The gun put away mid-reload: whoever waits on it is told.
GunnyAfterHolster(endLoopedWait)

-- The server took fewer shells than went in (they left the pockets mid-reload): the gun holds what was paid for.
RegisterNetEvent('whip_gunny:client:reloadShort', function(slot, pocket, ammo)
    if not CurrentWeapon or CurrentWeapon.slot ~= slot or CurrentWeapon.pocket ~= pocket then return end
    ammo = math.max(0, math.floor(tonumber(ammo) or 0))
    if ammo < GunnyAmmo.count() then GunnyAmmo.set(ammo) end
end)

--- R: a gun with a magazine swaps it for the fullest one carried; one without takes loose rounds.
local function reloadNow()
    if not CurrentWeapon then
        GunnyNotify('No weapon equipped', 'error')
        return
    end
    -- Guns only: R, B on a controller, and a seat's automatic reload (client/vehicle.lua) all come here.
    if not Config.IsFirearm(CurrentWeapon.config) then return end

    if isReloading then return end
    isReloading = true

    local weaponConfig = Config.GetWeapon(CurrentWeapon.name)
    if weaponConfig and weaponConfig.magless then
        local capacity = weaponConfig.internalCapacity
        if CurrentWeapon.ammo >= capacity then
            GunnyNotify('Already fully loaded', 'info')   -- nothing went wrong
            isReloading = false
            return
        end

        -- In a seat the game may play no animation: filled at once, as every other magless gun.
        if weaponConfig.loopedReload and not IsPedInAnyVehicle(PlayerPedId(), false) then
            shellByShellReload(capacity)
        else
            maglessReload()
        end
        return
    end

    -- The server first; the animation only once it has said yes (the top of this file says why the latch waits).
    local gun = CurrentWeapon

    local ok, result = GunnyCallback('whip_gunny:performReload', GunnySlot(gun.slot, gun.pocket))
    if not ok then
        GunnyNotify(type(result) == 'string' and result or 'Cannot reload', 'error')
        isReloading = false
        return
    end
    if CurrentWeapon ~= gun then reloadStoodDown() return end

    local ped = PlayerPedId()
    -- The new magazine and its count now. A change to the magazine slot during the animation replaces both
    -- (client/weapons.lua), and the animation leaves the gun as they are then.
    takeReloadAnswer(result)
    CurrentWeapon.magName = result.magazine

    GunnyAmmo.playReloadAnimation({
        waitForEnd  = true,
        minMs       = seatedMinMs(ped),
        -- Swap the visible magazine as soon as the task has hold, not after the wait, so the
        -- new magazine is on the weapon while the animation that fits it is still playing.
        onSettled   = function()
            -- The gun can be taken mid-reload (a forced holster doesn't wait).
            if CurrentWeapon ~= gun then return end
            GunnyApplyMagazine(ped, gun.hash, gun.name, gun.magName)
        end,
    })

    -- CurrentWeapon may have been cleared during the yield (death, holster, resource restart)
    if CurrentWeapon ~= gun then reloadStoodDown() return end

    GunnyAmmo.endAnimation(ped)

    GunnyReloading = false

    GunnyDebugCounts.lastReloadAt = GetGameTimer()

    GunnyDebugPrint('Reload complete -', gun.ammo, 'rounds, mag:', gun.magName or 'none')

    isReloading = false
end

--- The reload's thread (GunnyStartReload). Under a pcall: an error part way must not leave the latches on, which would
--- stop every shot being counted and every draw, holster and reload for the rest of the session. Firing comes back once
--- it is over, however it ended.
function GunnyReload()
    local ok, err = pcall(reloadNow)
    if not ok then
        print(('[GUNNY] reload failed: %s'):format(tostring(err)))
        GunnyAmmo.dropLoopedReload()
        endLoopedWait()
        reloadStoodDown()
        if CurrentWeapon then GunnyAmmo.set(GunnyAmmo.count()) end   -- the ped as the count says, no reserve left on it
    end
    underWay = false
    -- Two asked in one frame: the second stood down at once, and the first holds the keys until it ends.
    if not isReloading then holdFire(false) end
end

-- GTA's own reload and pistol-whip are held off while a gun is in the hand, through whip's control blocks
-- (/whipcontrols shows it). E is not: prompts and the furnisher read it.
local GUN_BLOCK = 'gunInHand'
local GUN_CONTROLS = { 45, 140, 141, 142, 143 }   -- R (reload), melee light / heavy / alternate, melee block
local gunKeysHeld = false

--- Held or let go, only when that changes. Held counts only once whip_core says yes; refused, it is asked again on
--- the next frame, and the reason said once.
local blockRefusalSaid = false
local function holdGunKeys(on)
    on = on == true
    if on == gunKeysHeld then return end
    local ok, why
    if on then ok, why = Whip.call('BlockControls', GUN_BLOCK, { controls = GUN_CONTROLS })
    else ok, why = Whip.call('UnblockControls', GUN_BLOCK) end
    if ok == true or not on then
        gunKeysHeld = on
    elseif not blockRefusalSaid then
        blockRefusalSaid = true
        print('[GUNNY] the reload and pistol-whip keys could not be held off: ' .. tostring(why))
    end
end

RegisterGunnyTick('controlBlock', function(ped)
    local inHand = GetSelectedPedWeapon(ped) == CurrentWeapon.hash
    -- Held off only for a gun, which would pistol-whip with them. A melee weapon is swung with these keys (R light, Q
    -- heavy, block); a throwable or the jerry can has nothing to reload.
    local gun = Config.IsFirearm(CurrentWeapon.config)
    holdGunKeys(inHand and gun)
    if not inHand then return end
    -- The weapon wheel stays hidden: the inventory is how a weapon is drawn in whip.
    HideHudComponentThisFrame(19)
end)

-- Put away mid-reload (a death, a forced holster): firing comes back now, not when a slow answer comes.
GunnyAfterHolster(function() holdGunKeys(false); holdFire(false) end)

-- On a controller, B on foot reloads: a pad action of whip's (RegisterPadAction) on that button, which presses
-- +gunny_reload as R does, so it is the same reload with the same checks, and players can move it on the Controller
-- screen. whip reads the button, so nothing here looks at it each frame. Ready only while a gun is drawn: whip then
-- holds GTA's own B (its reload and light punch) off; with none, or a melee weapon, B is GTA's.
local function gunDrawn() return CurrentWeapon ~= nil and Config.IsFirearm(CurrentWeapon.config) == true end
Whip.register(function()
    local ok, why = exports.whip_core:RegisterPadAction('gunny_reload', {
        label = 'Reload', command = '+gunny_reload', slot = 'foot_b', where = 'foot', ready = gunDrawn(),
    })
    if not ok then print('[GUNNY] no reload on the controller: ' .. tostring(why)) end
end)
GunnyAfterDraw(function() Whip.call('SetPadActionReady', 'gunny_reload', gunDrawn()) end)
GunnyAfterHolster(function() Whip.call('SetPadActionReady', 'gunny_reload', false) end)

-- An empty gun stays in the hand instead of GTA swapping it away. A FiveM switch that stays set until gunny
-- stops: once per draw, as each call adds a stop handler inside FiveM (every frame would pile them up).
GunnyAfterDraw(function() SetWeaponsNoAutoswap(true) end)

-- ============================================
-- G: CHECKING THE AMMO
-- ============================================

local isCheckingAmmo = false

local function ammoDescription(current, capacity)
    if capacity <= 0 then return 'No magazine.' end
    local percent = (current / capacity) * 100
    if percent >= 100 then return 'Full.'
    elseif percent >= 80 then return 'Almost full...'
    elseif percent >= 60 then return 'More than half...'
    elseif percent >= 40 then return 'Roughly half...'
    elseif percent >= 20 then return 'Less than half...'
    elseif percent >= 10 then return 'Looking low...'
    elseif percent >= 1 then return 'Basically empty...'
    else return 'Empty.' end
end

local function checkAmmo()
    if not CurrentWeapon then return end
    -- Guns only: the jerry can's level is on the item, a throwable's count is its stack
    if not Config.IsFirearm(CurrentWeapon.config) then return end
    if isCheckingAmmo then return end
    if isReloading then return end

    isCheckingAmmo = true

    local ped = PlayerPedId()
    local gun = CurrentWeapon
    -- A peek, not a reload: the gesture is borrowed, and the round count is put back exactly
    -- as it was.
    GunnyAmmo.playReloadAnimation({ settleMs = 50 })
    -- Put away meanwhile (a death): nothing to read, and the latch goes.
    if CurrentWeapon ~= gun then isCheckingAmmo = false return end

    local capacity = 0   -- a gun with no magazine in it
    local weaponConfig = Config.GetWeapon(gun.name)
    if weaponConfig and weaponConfig.magless then
        capacity = weaponConfig.internalCapacity
    elseif gun.magName then
        local magConfig = Config.GetMagazine(gun.magName)
        if magConfig then
            capacity = magConfig.capacity
        end
    end
    local current = gun.ammo or 0
    local description = ammoDescription(current, capacity)

    Wait(450)

    GunnyAmmo.endAnimation(ped)

    -- A reading, not a failure: shown as info.
    GunnyNotify(description, 'info')

    GunnyDebugPrint('Ammo check:', current, '/', capacity, '-', description)

    isCheckingAmmo = false
end

-- The ammo check's keybind: G. With sticky bombs out it sets them off instead (client/throwables.lua), drawn
-- or not, as G does in GTA: the one key, so a check never plays while the player means to detonate.
RegisterCommand('+gunny_check_ammo', function()
    -- G is the furnisher's snap key too.
    if Whip.call('IsGameInputFree') ~= true then return end
    if GunnyDetonateStickyBombs() then return end

    if not CurrentWeapon then return end
    if isCheckingAmmo then return end
    if isReloading then return end

    checkAmmo()
end, false)
RegisterCommand('-gunny_check_ammo', function() end, false)
RegisterKeyMapping('+gunny_check_ammo', 'Check Ammo / Detonate Sticky Bombs', 'keyboard', 'g')

-- On a controller: LB + B, unless the player moved it (the pause menu's Controller screen).
Whip.register(function()
    local ok, why = exports.whip_core:RegisterPadAction('gunny_check_ammo', {
        label = 'Check ammo / detonate', command = '+gunny_check_ammo', slot = 'lb_b',
    })
    if not ok then print('[GUNNY] no check ammo on the controller: ' .. tostring(why)) end
end)
