-- whip_gunny — DRAWING AND PUTTING AWAY (client)
--
-- The server says what is drawn (server/weapons.lua); this puts it in the hands, with its rounds, magazine and
-- attachments, and takes it out again. CurrentWeapon (client/main.lua) is the drawn gun, nil when none.

--- The draw and holster animations. Loaded once and kept: every equip and holster plays them.
local EQUIP_ANIM_DICT = 'reaction@intimidation@cop@unarmed'

CreateThread(function()
    if Whip.call('LoadAnimDict', EQUIP_ANIM_DICT, 10000) ~= true then
        print('[GUNNY] equip animation dictionary failed to preload — equipping will still work, just less smoothly')
    end
end)

local DRAW_END_WAIT_MS = 300

--- End the draw's animation if it is still on the upper body, and wait until it has gone (call from a thread).
---
--- The draw's 'intro' blends out for about a second after the gun is in the hand. A reload started under it is
--- started over by the game when the draw lets go, so every reload-style animation calls this first (client/ammo.lua).
---@param ped number
function GunnyEndDrawAnim(ped)
    if not IsEntityPlayingAnim(ped, EQUIP_ANIM_DICT, 'intro', 3) then return end
    StopAnimTask(ped, EQUIP_ANIM_DICT, 'intro', 8.0)
    local giveUp = GetGameTimer() + DRAW_END_WAIT_MS
    while IsEntityPlayingAnim(ped, EQUIP_ANIM_DICT, 'intro', 3) and GetGameTimer() < giveUp do Wait(0) end
end

--- Weapon hash -> item key, built on first use, and again after a weapon pack's item arrives or goes.
local _hashToName = nil
GunnyPacks.onChange(function() _hashToName = nil end)

local function weaponByHash(hash)
    if not _hashToName then
        _hashToName = {}
        for name, cfg in pairs(Config.Weapons or {}) do
            if cfg.hash then _hashToName[cfg.hash] = name end
        end
    end
    return _hashToName[hash]
end

--- whip_core's weapon guard takes away any GTA weapon nothing permits: on before the give, off after the removal. A
--- refused permit is said, once per gun: the guard would take that gun out of the hands with no word of why.
local permitRefusalSaid = {}
local function permitGun(hash, on)
    if not hash then return end
    local ok = Whip.call('PermitNativeWeapon', hash, on)
    if on and ok ~= true and not permitRefusalSaid[hash] then
        permitRefusalSaid[hash] = true
        print(('[GUNNY] WARNING: whip_core\'s weapon guard did not permit weapon %s, so it may take it away'):format(tostring(hash)))
    end
end

--- The magazine the gun shows: every clip component off, then this magazine's, or the gun's own when it has none or
--- no magazine is in.
function GunnyApplyMagazine(ped, weaponHash, weaponName, magName)
    if not ped or not weaponHash or not weaponName then return end
    for _, componentHash in ipairs(Config.GetAllClipComponents(weaponName)) do
        if HasPedGotWeaponComponent(ped, weaponHash, componentHash) then
            RemoveWeaponComponentFromPed(ped, weaponHash, componentHash)
        end
    end
    local weaponConfig = Config.GetWeapon(weaponName)
    local component = (magName and Config.GetMagComponent(magName)) or (weaponConfig and weaponConfig.defaultClipComponent)
    if component then GiveWeaponComponentToPed(ped, weaponHash, component) end
end

--- Is this pocket slot the drawn gun's?
local function isDrawn(slot, pocket)
    return CurrentWeapon ~= nil and CurrentWeapon.slot == slot and CurrentWeapon.pocket == pocket
end

-- ============================================
-- AFTER A DRAW OR A HOLSTER: gunny's own steps, then everyone's event
-- ============================================
--
-- gunny's other files react through these (its key blocks, the ammo sync, the bench), in order, before
-- whip_gunny:weapon:drawn / :holstered tell other resources. So nothing firing those events can release gunny's key
-- blocks or close its bench.

local afterDraw, afterHolster = {}, {}

--- fn(gun) once a weapon is drawn: gun is CurrentWeapon.
function GunnyAfterDraw(fn) afterDraw[#afterDraw + 1] = fn end

--- fn(gun) once it is put away, however it went: gun is the record it was.
function GunnyAfterHolster(fn) afterHolster[#afterHolster + 1] = fn end

local function runSteps(steps, gun)
    for _, fn in ipairs(steps) do
        local ok, err = pcall(fn, gun)
        if not ok then print(('[GUNNY] a step after a draw or holster errored: %s'):format(tostring(err))) end
    end
end

-- One equip at a time. The latch has a deadline, so a server that never answers cannot block equipping for good.
local isEquipping = false
local equipStartedAt = 0
local EQUIP_TIMEOUT = 10000

--- The draw in flight, from asking the server until the gun is in the hand (CurrentWeapon is still nil, so the
--- handlers below would drop what arrives). What the server says meanwhile is kept and applied as the draw ends:
--- `holster` (it took the gun back: the draw is called off) and `count` (a drawn stack changed).
local drawing = nil

--- Keep the server's word for the draw in flight. false: none in flight.
---@param what 'holster'|'count'
---@param value number|nil  the stack's count, for 'count'
---@return boolean
function GunnyDrawNote(what, value)
    if not drawing then return false end
    if what == 'holster' then drawing.holster = true else drawing.count = value end
    return true
end

--- Is an equip in flight, or did one get stuck?
local function equipInProgress()
    if not isEquipping then return false end
    if GetGameTimer() - equipStartedAt > EQUIP_TIMEOUT then
        print('[GUNNY] equip lock expired after ' .. EQUIP_TIMEOUT .. 'ms — the server never answered. Releasing.')
        isEquipping = false
        return false
    end
    return true
end

local function beginEquip()
    isEquipping = true
    equipStartedAt = GetGameTimer()
end

--- Put the drawn gun back on the server: its count, and it is no longer in the hand. Waits. The count goes with its
--- version: one from before the server's last change to the gun is ignored there (GunnyCountChanged).
---@param ammo number|nil
---@param countVersion number|nil
---@return boolean ok
local function tellHolstered(ammo, countVersion)
    return GunnyCallback('whip_gunny:holsterWeapon', ammo or 0, countVersion or 0) == true
end

--- Draw the weapon in this pocket slot. `quick`: straight into the hand with no draw animation (Equip on a gun just
--- picked up, whose grab already showed it coming up). Waits; answers true (drawn, or already was) or false and why.
---@return boolean ok
---@return string|nil why
function DrawWeapon(slot, pocket, quick)
    pocket = pocket or 'player'
    if isDrawn(slot, pocket) then return true end
    if equipInProgress() then return false, 'Already drawing a weapon' end   -- a second press: no word needed
    if GunnyReloadUnderWay() then   -- asked for or playing (client/reload.lua): the gun in hand is not put away for it
        GunnyNotify('Finish reloading first', 'error')
        return false, 'Finish reloading first'
    end
    -- A resource has blocked the hands, or weapons (whip_core's BlockHands): a no-weapons zone, a restraint.
    local blocked, why = Whip.call('AreHandsBlocked', 'weapon')
    if blocked == true then
        GunnyNotify(why, 'error')
        return false, why
    end

    -- Another gun out: away first (waits out its animation). The latch goes on before, so nothing starts between.
    beginEquip()
    if CurrentWeapon then GunnyHolster() end

    -- The animation starts before the round trip, so the wait hides inside it.
    local ped = PlayerPedId()
    local animStartedAt = GetGameTimer()
    if not quick then
        TaskPlayAnim(ped, EQUIP_ANIM_DICT, 'intro', 8.0, 1.0, 500, 50, 0, false, false, false)
    end

    local draw = {}
    drawing = draw
    local success, drawn = GunnyCallback('whip_gunny:equipWeapon', GunnySlot(slot, pocket))
    if not success then
        local refused = type(drawn) == 'string' and drawn or 'Cannot equip weapon'
        GunnyNotify(refused, 'error')
        drawing, isEquipping = nil, false
        return false, refused
    end
    local hash, ammo, magName, attachments = drawn.hash, drawn.ammo, drawn.magazine, drawn.attachments
    GunnyDebugPrint('Equip', slot, pocket, '- server:', hash, ammo, magName)

    local weaponName = weaponByHash(hash)
    local weaponConfig = weaponName and Config.Weapons[weaponName] or nil
    if not weaponName then
        -- The server has it drawn: it goes back there too, or the record and the held item would stay.
        drawing = nil
        tellHolstered(ammo, drawn.countVersion)
        GunnyNotify('Unknown weapon hash', 'error')
        isEquipping = false
        return false, 'Unknown weapon hash'
    end

    -- Only what is left of the animation: the round trip ran during it.
    local remaining = quick and 0 or 300 - (GetGameTimer() - animStartedAt)
    if remaining > 0 then Wait(remaining) end
    drawing = nil

    -- Died during the draw: the death holster found no gun yet, so it goes back on the server, and nothing is given.
    if Whip.call('IsPlayerDead') == true then
        if not tellHolstered(ammo, drawn.countVersion) then
            print('[GUNNY] WARNING: the server refused the holster of a gun drawn as the player died')
        end
        isEquipping = false
        return false, 'Dead'
    end

    -- The server took it back during the draw (moved out of its slot, a logout, whip_core gone). Put away there too,
    -- in case the word was for the gun before this one; a refusal is only said (the record is already gone).
    if draw.holster then
        if not tellHolstered(ammo, drawn.countVersion) then
            GunnyDebugPrint('Holster after a called-off draw: the server had no record')
        end
        isEquipping = false
        return false, 'The weapon left its slot'
    end
    ped = PlayerPedId()   -- the round trip may have outlived the ped it started on

    -- A weapon this build of the game does not have (the acid package and the newspaper need a recent one).
    if not IsWeaponValid(hash) then
        if not tellHolstered(ammo, drawn.countVersion) then
            print('[GUNNY] WARNING: the server refused the holster of a weapon this game build does not have')
        end
        local missing = ('This server\'s version of the game has no %s'):format(weaponConfig.label or weaponName)
        GunnyNotify(missing, 'error')
        isEquipping = false
        return false, missing
    end

    local throwable = Config.IsThrowable(weaponConfig)

    -- A drawn stack that changed during the draw: the new count, never more than the equip gave.
    if throwable and draw.count then ammo = math.min(ammo or 0, draw.count) end

    -- GTA will not hand over a throwable with none, so a stack is given with its count.
    permitGun(hash, true)
    GiveWeaponToPed(ped, hash, throwable and (ammo or 0) or 0, false, true)
    SetCurrentPedWeapon(ped, hash, true)

    if Config.IsFirearm(weaponConfig) and not weaponConfig.magless then
        GunnyApplyMagazine(ped, hash, weaponName, magName)
    end

    attachments = attachments or {}
    if next(attachments) then
        ApplyWeaponAttachments(ped, hash, weaponName, attachments)
    end

    SetPedCurrentWeaponVisible(ped, true, false, false, false)

    CurrentWeapon = {
        slot = slot,
        pocket = pocket,
        name = weaponName,
        hash = hash,
        serial = drawn.serial,
        config = weaponConfig,
        ammo = 0,
        metadata = { attachments = attachments },
        magName = magName,
        shotsInFlight = 0,   -- shots sent and not yet answered (client/shooting.lua)
        countVersion = drawn.countVersion or 1,   -- sent with every count (GunnyCountChanged on the server)
    }
    GunnyStartTick()   -- the gun can fire from now: its shots are counted from the next frame (client/main.lua)
    -- Its rounds, through client/ammo.lua, the one writer of a ped's ammunition: a throwable's stack has no clip, a
    -- melee weapon no rounds.
    if throwable then
        GunnyAmmo.setStack(ammo or 0)
    elseif not Config.IsMelee(weaponConfig) then
        GunnyAmmo.set(ammo or 0)
    end
    GunnyDebugPrint('Equipped', weaponName, 'with', ammo, 'rounds, mag:', magName or 'none')

    isEquipping = false
    runSteps(afterDraw, CurrentWeapon)
    TriggerEvent('whip_gunny:weapon:drawn', GetDrawnWeapon())
    return true
end

--- The drawn gun out of the hands and forgotten here (`remove` false: the game already took it). Answers it.
---@param ped number
---@param remove boolean
---@return table gun  the record it was
local function letGo(ped, remove)
    local gun = CurrentWeapon
    ---@cast gun -nil   -- called only with a gun drawn
    if remove then RemoveWeaponFromPed(ped, gun.hash) end
    permitGun(gun.hash, false)
    CurrentWeapon = nil
    runSteps(afterHolster, gun)
    TriggerEvent('whip_gunny:weapon:holstered', { item = gun.name, slot = gun.slot, pocket = gun.pocket })
    return gun
end

--- What is left in the drawn weapon. The jerry can's is read off the ped: GTA pours it, and the tracked figure is up
--- to half a second behind (client/shooting.lua).
local function roundsLeft(ped)
    local ammo = CurrentWeapon.ammo
    if Config.IsFuelCan(CurrentWeapon.config) then
        ammo = math.min(ammo or 0, GetAmmoInPedWeapon(ped, CurrentWeapon.hash))
    end
    return ammo
end

--- Firing and aiming held off while a gun goes away, on foot and in a seat (whip's control blocks: /whipcontrols shows
--- it). The server is told the count as the animation starts, and a shot after that would have no draw to be charged
--- to. Held only by the holster's own body; GunnyHolster lets go however it ends.
local AWAY_BLOCK = 'gunGoingAway'
local fireHeld = false
local function holdFire(on)
    if on == fireHeld then return end
    fireHeld = on
    local ok, why
    if on then ok, why = Whip.call('BlockControls', AWAY_BLOCK, { groups = { 'combat', 'vehicleCombat' } })
    else ok, why = Whip.call('UnblockControls', AWAY_BLOCK) end
    if ok ~= true then GunnyDebugPrint('Holster: the fire keys could not be', on and 'held' or 'let go', why) end
end

--- Holster: the body, run one at a time by GunnyHolster.
---@param serverDropped boolean|nil  the server has already put it away (whip_gunny:client:forceHolster)
---@param now boolean|nil  out of the hands at once, no animation, even mid-reload: dying, or the hands blocked
local function holsterInner(serverDropped, now)
    if not CurrentWeapon then return end
    local ped = PlayerPedId()

    -- The server already took it (moved, dropped, stashed, handed over, logout, whip_core gone): out of the hands
    -- now, no animation, no waiting for a reload. A reload in flight sees CurrentWeapon gone and stands down.
    if serverDropped then
        letGo(ped, true)
        return
    end

    -- At once (dying: the death gives the player a new ped; the hands blocked during a reload): out of the hands, then
    -- the server is told the count (its holsterWeapon accepts a dead player). A reload in flight stands down.
    if now then
        GunnyThrowSettle(ped)   -- a throwable thrown, or a cooked one dropped, as they died: told first
        local ammo, countVersion = roundsLeft(ped), CurrentWeapon.countVersion
        letGo(ped, true)
        if not tellHolstered(ammo, countVersion) then
            print('[GUNNY] WARNING: the server refused the holster, ammo may not have saved')
        end
        return
    end

    -- Mid-reload the gun stays out (a death or a block uses `now`, above): said, so the press is not lost in silence.
    -- From R, not only once the animation plays: the server swaps the magazine as it answers, and a gun put away while
    -- it answered would get the new one with no reload played (client/reload.lua).
    if GunnyReloadUnderWay() then
        GunnyNotify('Finish reloading first', 'error')
        return
    end

    -- Nothing fires from here on, so the count read next is the last one.
    holdFire(true)
    GunnyThrowSettle(ped)   -- a throwable thrown a moment ago: told before it is put away
    local ammo = roundsLeft(ped)

    -- The animation first, and the server told while it plays. Refused, it is put away anyway (a gun left out is
    -- worse), and said.
    local animStartedAt = GetGameTimer()
    TaskPlayAnim(ped, EQUIP_ANIM_DICT, 'outro', 8.0, 1.0, 500, 50, 0, false, false, false)
    if not tellHolstered(ammo, CurrentWeapon.countVersion) then
        print('[GUNNY] WARNING: server refused the holster — putting the weapon away anyway, ammo may not have saved')
    end

    local remaining = 300 - (GetGameTimer() - animStartedAt)
    if remaining > 0 then Wait(remaining) end

    -- Gone meanwhile (death, a restart): nothing left to remove.
    if not CurrentWeapon then return end
    letGo(ped, true)
    GunnyDebugPrint('Holstered weapon')
end

--- One holster at a time (two can arrive together: a forceHolster as the player dies). The one under way, as a
--- promise a second caller waits on.
local holstering = nil

--- Is the drawn gun on its way out of the hands? R does nothing meanwhile (client/reload.lua).
---@return boolean
function GunnyPuttingAway()
    return holstering ~= nil
end

---@param serverDropped boolean|nil  the server has already put it away (whip_gunny:client:forceHolster)
---@param now boolean|nil  at once, no animation (a death, a block during a reload: below)
function GunnyHolster(serverDropped, now)
    if holstering then
        -- Wait for the one under way, so a caller that draws next (DrawWeapon) starts after the old gun is gone.
        Citizen.Await(holstering)
        return
    end
    local done = promise.new()
    holstering = done
    local ok, err = pcall(holsterInner, serverDropped, now)
    holdFire(false)   -- every way out, an error too
    holstering = nil
    done:resolve(true)
    if not ok then print('[GUNNY] holster failed: ' .. tostring(err)) end
end

--- The inventory's Equip: draw it, or put it away if it is the one drawn.
---@param quick boolean|nil  straight into the hand, no draw animation (DrawWeapon)
local function toggleDraw(slot, pocket, quick)
    pocket = pocket or 'player'
    if isDrawn(slot, pocket) then
        GunnyHolster()
    else
        DrawWeapon(slot, pocket, quick)
    end
end

-- Putting it away is whip_core's FreeHands(), which empties the hands of whatever is in them; gunny answers it. Mid-
-- reload it answers false, and the gun stays out until the reload ends (client/main.lua).
exports('DrawWeapon', function(slot, pocket) return DrawWeapon(slot, pocket) end)

-- The drawn gun left the slot it was drawn from (dragged away, stashed, handed over): the server has let it go.
-- During a draw it calls the draw off (GunnyDrawNote).
RegisterNetEvent('whip_gunny:client:forceHolster', function()
    if CurrentWeapon then GunnyHolster(true) else GunnyDrawNote('holster') end
end)

-- A logout puts it away, so the next character does not start with this one's gun. The server already let it go.
AddEventHandler('whip_core:player:logout', function()
    if CurrentWeapon then GunnyHolster(true) else GunnyDrawNote('holster') end
end)
AddEventHandler('whip_core:player:died', function()
    if CurrentWeapon then GunnyHolster(false, true) end
end)
-- The hands were blocked with a gun out (every block stops weapons): put away with its animation, or at once when a
-- reload is under way (an ordinary holster waits for none, and the block is said only once). During a draw it calls
-- the draw off, as the server taking the gun back does.
AddEventHandler('whip_core:hands:blocked', function()
    if CurrentWeapon then
        CreateThread(function() GunnyHolster(false, GunnyReloadUnderWay()) end)
    else
        GunnyDrawNote('holster')
    end
end)

-- Equip from the inventory (the context action, server/items.lua). `quick`: Equip on a gun just picked up off the
-- ground.
RegisterNetEvent('whip_gunny:client:useWeapon', function(slot, pocket, quick)
    toggleDraw(slot, pocket, quick == true)
end)

-- ============================================
-- THE MAGAZINE SLOT CHANGED WITH THE GUN IN THE HAND (server/magpanel.lua)
-- ============================================
--
-- The reload gesture, then the new count. A magazine going in or out also changes the magazine the gun shows.

---@param weaponSlot number
---@param rounds number         what the gun holds after
---@param countVersion number   the count's version from now on (GunnyCountChanged on the server)
---@param holdMs number|nil     how long the gesture plays; nil: none, the count only
---@param settleMs number|nil
---@param mag table|nil         { name } when the magazine changed (name nil: it came out)
local function slotChanged(weaponSlot, rounds, countVersion, holdMs, settleMs, mag)
    if not CurrentWeapon or CurrentWeapon.slot ~= weaponSlot then return end
    -- The count and its version at once: the ammo sync and a holster send them from now on.
    rounds = math.max(0, math.floor(tonumber(rounds) or 0))
    CurrentWeapon.countVersion = tonumber(countVersion) or CurrentWeapon.countVersion
    local ped = PlayerPedId()
    if mag then
        GunnyApplyMagazine(ped, CurrentWeapon.hash, CurrentWeapon.name, mag.name)
        CurrentWeapon.magName = mag.name
    end
    -- A reload's animation is playing: it leaves the gun with this count as it ends (client/ammo.lua).
    if GunnyReloading then
        CurrentWeapon.ammo = rounds
        return
    end
    GunnyAmmo.set(rounds)   -- the ped too, so a shot before the gesture takes hold is counted from it
    if not holdMs then return end   -- the count only: no gesture
    local inCover = IsPedInCover(ped, false)
    GunnyAmmo.playReloadAnimation({ settleMs = settleMs })
    Wait(holdMs)
    GunnyAmmo.endAnimation(ped, inCover)
end

local function reloadTimeOf() return CurrentWeapon and CurrentWeapon.config.reloadTime or 1500 end

RegisterNetEvent('whip_gunny:client:magazineInserted', function(weaponSlot, magAmmo, countVersion, magName)
    slotChanged(weaponSlot, magAmmo, countVersion, reloadTimeOf(), nil, { name = magName })
end)

RegisterNetEvent('whip_gunny:client:magazineRemoved', function(weaponSlot, countVersion)
    slotChanged(weaponSlot, 0, countVersion, 450, 50, { name = nil })
end)

RegisterNetEvent('whip_gunny:client:maglessAmmoInserted', function(weaponSlot, newAmmoCount, countVersion)
    slotChanged(weaponSlot, newAmmoCount, countVersion, math.min(reloadTimeOf(), 1000))
end)

RegisterNetEvent('whip_gunny:client:maglessAmmoRemoved', function(weaponSlot, remainingAmmo, countVersion)
    slotChanged(weaponSlot, remainingAmmo, countVersion, 450, 50)
end)

-- A reload undone on the server (the old magazine had nowhere to go, server/reload.lua): the old magazine is back in,
-- with its count and the count's new version. No gesture: nothing changed in the hand.
RegisterNetEvent('whip_gunny:client:countRestored', function(weaponSlot, magAmmo, countVersion, magName)
    slotChanged(weaponSlot, magAmmo, countVersion, nil, nil, { name = magName })
end)

-- Something else took the gun out of the hands (another script, or GTA with a throwable's last one thrown): put away
-- here and on the server, with the count kept. Looked at once a second, on the tick. Leaving its slot is the server's
-- to see (whip_core:inventory:changed, server/weapons.lua), and it sends whip_gunny:client:forceHolster.
local GONE_CHECK_MS = 1000
local goneCheckAt = 0

RegisterGunnyTick('weaponGone', function(ped, now)
    if now < goneCheckAt then return end
    goneCheckAt = now + GONE_CHECK_MS
    if HasPedGotWeapon(ped, CurrentWeapon.hash, false) then return end
    GunnyDebugPrint('Weapon removed from ped - force holstering')
    GunnyThrowSettle(ped)   -- GTA takes a throwable away with the last one thrown: told first
    local gun = letGo(ped, false)
    CreateThread(function() tellHolstered(gun.ammo, gun.countVersion) end)   -- its own thread: the call waits
end)

-- Stopping: the GTA weapon goes too, so it does not stay in the hand with nothing tracking it.
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if CurrentWeapon and CurrentWeapon.hash then
        RemoveWeaponFromPed(PlayerPedId(), CurrentWeapon.hash)
    end
    CurrentWeapon = nil
end)
