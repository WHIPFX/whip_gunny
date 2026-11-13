-- whip_gunny — SHOTS (client)
--
-- The client counts shots; the server decides the round count.
--
-- The server holds the number. Both client corrections (the periodic sync here and the holster
-- report) are accepted only when lower: firing only reduces a count, so a higher claim would be a
-- free reload. The client counts because it sees the trigger frame by frame; it isn't the final word.

local SYNC_INTERVAL = 5000
local lastSyncedAmmo = -1
local lastSyncTime = 0

-- The jerry can pours, it doesn't fire. GTA empties it while pouring, so its level is read off the ped
-- twice a second and a lower figure goes to the server about once a second (it only accepts lower).
local FUEL_READ_MS, FUEL_SYNC_MS = 500, 1000
local fuelReadAt, fuelSyncAt = 0, 0

-- A gun that runs dry mid-fire on foot is left stuck in GTA's aim task: it keeps acting out the shot it
-- can't fire, every frame (the slapping pistol, the minigun spinning on after the trigger is let go). Only
-- a new aim task clears it: letting go of aim, or a reload. So DRY_SETTLE_MS after the last round (its
-- recoil plays out first; any sooner cuts it off), the aim is ended the way check ammo ends it, held
-- trigger or not; held aim comes straight back, on a gun that clicks empty. A seat reloads by itself
-- instead (client/vehicle.lua).
local DRY_SETTLE_MS = 150
local dryAt = nil   -- when the last round left on foot, until the aim is ended

local function dryTick(ped, now)
    if (CurrentWeapon.ammo or 0) > 0 or GunnyReloading then dryAt = nil; return end
    if now - dryAt < DRY_SETTLE_MS then return end
    if IsPedInAnyVehicle(ped, false) or GetSelectedPedWeapon(ped) ~= CurrentWeapon.hash then dryAt = nil; return end
    -- Not mid-air or mid-climb: clearing the tasks would drop that too. It waits for the feet.
    if IsPedRagdoll(ped) or IsPedFalling(ped) or IsPedJumping(ped) or IsPedClimbing(ped) then return end
    dryAt = nil
    GunnyAmmo.endAnimation(ped)
end

local function pourTick(ped, now)
    if now - fuelReadAt < FUEL_READ_MS then return end
    fuelReadAt = now
    local left = GetAmmoInPedWeapon(ped, CurrentWeapon.hash)
    if left < (CurrentWeapon.ammo or 0) then CurrentWeapon.ammo = left end
    if CurrentWeapon.ammo ~= lastSyncedAmmo and now - fuelSyncAt >= FUEL_SYNC_MS then
        fuelSyncAt = now
        lastSyncedAmmo = CurrentWeapon.ammo
        TriggerServerEvent('whip_gunny:server:syncAmmo', CurrentWeapon.ammo, CurrentWeapon.countVersion)
    end
end

-- The can's level from the server (filled at a pump, or poured into a car: server/weapons.lua). Its own
-- message, not whip_gunny:client:syncAmmo, which answers a shot. Applies to the can in hand only. With the
-- count's new version: what the client sends from now on is counted from this level.
RegisterNetEvent('whip_gunny:client:syncFuel', function(ammo, countVersion)
    if not (CurrentWeapon and Config.IsFuelCan(CurrentWeapon.config)) then return end
    CurrentWeapon.countVersion = tonumber(countVersion) or CurrentWeapon.countVersion
    GunnyAmmo.set(ammo)
    lastSyncedAmmo = CurrentWeapon.ammo   -- the server's own figure: nothing to send back
end)

-- Shot detection + periodic sync (runs in main.lua's single tick thread, which hands it the ped
-- and the time)
RegisterGunnyTick('shooting', function(ped, now)
    local cfg = CurrentWeapon.config
    -- A melee weapon fires nothing and holds no rounds: no shots to count, no count to sync.
    if Config.IsMelee(cfg) then return end
    if Config.IsFuelCan(cfg) then return pourTick(ped, now) end
    -- A throwable is thrown, not fired: what left the hand is counted off GTA's own count (client/throwables.lua).
    if Config.IsThrowable(cfg) then return GunnyThrowSettle(ped) end

    if dryAt then dryTick(ped, now) end

    -- A shell-at-a-time reload ends in the frame it ends, and lifts the latch: a shot that stopped it is
    -- counted just below (client/reload.lua).
    GunnyLoopedReloadTick(ped, now)

    if not GunnyReloading then
        if IsPedShooting(ped) and CurrentWeapon.ammo > 0 then
            -- As many rounds as GTA took this frame: more than one at a low frame rate with a fast gun.
            local rounds = GunnyAmmo.roundsFired(ped)
            GunnyAmmo.spend(rounds)
            CurrentWeapon.shotsInFlight = CurrentWeapon.shotsInFlight + 1   -- answered by whip_gunny:client:syncAmmo, below
            -- Gunny Debug's counts (client/debug.lua): reports sent against reports answered.
            GunnyDebugCounts.sent = GunnyDebugCounts.sent + 1
            GunnyDebugCounts.lastShotAt = now

            TriggerServerEvent('whip_gunny:server:shotFired', rounds)

            GunnyDebugPrint('Fired', rounds, 'rounds - Ammo left:', CurrentWeapon.ammo)

            -- The last round: a seat reloads by itself (client/vehicle.lua); on foot the stuck aim is ended.
            if CurrentWeapon.ammo == 0 then
                if IsPedInAnyVehicle(ped, false) then GunnyReloadInVehicle() else dryAt = now end
            end
        end
    end

    -- Periodic ammo sync (backup, only when ammo changed)
    if now - lastSyncTime >= SYNC_INTERVAL then
        lastSyncTime = now
        if not GunnyReloading and CurrentWeapon.ammo ~= lastSyncedAmmo then
            lastSyncedAmmo = CurrentWeapon.ammo
            -- For the ammo ledger: a count below the server's last answer takes the server down with it.
            local said = GunnyDebugCounts.serverAmmo
            if said and CurrentWeapon.ammo < said then
                GunnyDebugPrint('5 s sync sends', CurrentWeapon.ammo, 'below the server\'s last', said, 'with',
                    CurrentWeapon.shotsInFlight, 'shots unanswered')
            end
            -- With its version: one counted before the server's last change to the gun is ignored there.
            TriggerServerEvent('whip_gunny:server:syncAmmo', CurrentWeapon.ammo, CurrentWeapon.countVersion)
        end
    end
end)

-- The server's count after each shot it took (server/shooting.lua), one answer per shot sent.
RegisterNetEvent('whip_gunny:client:syncAmmo', function(ammo)
    -- Gunny Debug's view (client/debug.lua), before the client's count is overwritten below.
    local dbg = GunnyDebugCounts
    dbg.serverAmmo, dbg.serverAmmoAt, dbg.confirmed = ammo, GetGameTimer(), dbg.confirmed + 1

    if not CurrentWeapon then return end
    local current = CurrentWeapon.ammo or 0
    CurrentWeapon.shotsInFlight = math.max(0, CurrentWeapon.shotsInFlight - 1)

    -- During automatic fire each answer describes the magazine some shots ago (the client at 27 with three shots in
    -- flight, the server answering 29): a higher count while shots are still unanswered is old, and ignored. A
    -- lower one always applies: the server is the authority.
    if ammo > current and CurrentWeapon.shotsInFlight > 0 then
        dbg.staleIgnored = dbg.staleIgnored + 1
        return
    end

    -- A higher count with nothing in flight is a real fault, not lag: counted for Gunny Debug.
    if ammo > current then
        local reloadRecently = GunnyReloading
            or (dbg.lastReloadAt and (GetGameTimer() - dbg.lastReloadAt) < 1500)
        if not reloadRecently then
            dbg.ammoJumps = dbg.ammoJumps + 1
            dbg.lastJump  = { from = current, to = ammo, at = GetGameTimer() }
        end
    end

    -- A reload's animation is playing (an answer to a shot fired while R was being asked): the count only. The
    -- animation leaves the gun with it as it ends (client/ammo.lua); on the ped now, those rounds could be fired while
    -- no shot is counted.
    if GunnyReloading then
        local n = math.max(0, math.floor(tonumber(ammo) or 0))
        -- For the ammo ledger: an answer that takes the count below what the reload gave.
        if n < current then
            dbg.reloadLowered = dbg.reloadLowered + (current - n)
            GunnyDebugPrint('An answer during the reload took the count from', current, 'to', n)
        end
        CurrentWeapon.ammo = n
        return
    end
    GunnyAmmo.set(ammo)
end)

-- A new weapon in the hand, or none: the sync starts over.
GunnyAfterDraw(function()
    lastSyncTime = GetGameTimer()
    lastSyncedAmmo = -1
    dryAt = nil
end)

GunnyAfterHolster(function()
    lastSyncedAmmo = -1
    dryAt = nil
end)
