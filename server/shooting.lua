-- whip_gunny — SHOTS (server)
--
-- The client counts shots (it sees the trigger frame by frame); the server holds the number. Each shot takes a round
-- from the drawn gun's magazine or chamber, and the client's own count is only ever believed when it is lower.
--
-- A shot fired in the frame the gun is put away can be counted after the holster read its count, so it arrives just
-- behind the holster. It is still charged to that gun, as long as it sits where it was drawn from (GunnyDrawnWeapon's
-- `lateToo`): dropped, the round would come back with the next draw. Nothing is sent back for it: the hand holds
-- nothing now, or the next gun.

--- Rounds this player's drawn gun spent, for other resources: whip_gunny:weapon:fired, once per batch the server
--- took (a burst arrives as a few, a missed shot with the next sync).
local function fired(source, slotData, equipped, shots, ammo)
    local ped = GetPlayerPed(source)
    TriggerEvent('whip_gunny:weapon:fired', { source = source, item = slotData.item, serial = equipped.serial,
        shots = shots, ammo = ammo, coords = ped ~= 0 and GetEntityCoords(ped) or nil })
end

--- A shot left the barrel.
RegisterGunnyEvent('whip_gunny:server:shotFired', {
    whileDead = true,   -- a round fired just before dying is still spent
    -- The light player sheet: the handler never reads `player`, and this fires up to ~66 times a second per shooter.
    sheet = 'light',
    -- Above any weapon's fire rate (whip_core's default is below a minigun's), but not unlimited: each shot is a
    -- metadata write. 15 ms, burst 30 ≈ 66 shots/s. A dropped shot is never charged.
    rateLimit = 15,
    burst     = 30,
    params = {
        -- Bounded: one trigger pull cannot claim to have emptied a magazine.
        {'shotsFired', 'int', 1, 10, 1},
    },
}, function(source, _, shotsFired)
    -- The server's own record of the drawn gun (or the one just put away: the top of this file), still in the slot it
    -- was drawn from: one moved away is put away rather than fired for free.
    local slotData, equipped, late = GunnyDrawnWeapon(source, true)
    if not equipped then
        GunnyDebugPrint('Shot fired event but weapon not tracked as equipped')
        GunnyNoDrawRecord(source)
        return
    end
    if not slotData then
        if not late then GunnyForceHolster(source) end
        return
    end
    local addr = GunnyPocket(source, equipped.pocket, equipped.slot)

    local weaponConfig = Config.GetWeapon(slotData.item)
    if not weaponConfig then return end
    -- The jerry can fires nothing: what it pours comes as its level (whip_gunny:server:syncAmmo, below).
    if Config.IsFuelCan(weaponConfig) then return end

    local meta = slotData.metadata or {}
    local newAmmo, before = 0, 0

    -- A gun with no magazine holds its rounds itself; any other, in its magazine.
    if weaponConfig.magless then
        before = meta.ammo or 0
        newAmmo = math.max(0, before - shotsFired)
        meta.ammo = newAmmo
        GunnyDebugPrint('Magless shot fired - Ammo remaining:', newAmmo)
    else
        -- No magazine in it here, yet the hand fired: the client's count is wrong (the magazine came out mid-reload).
        -- Told 0, it stops at this shot instead of firing rounds that are in a magazine in the pockets.
        if not meta.magazine then
            if not late then TriggerClientEvent('whip_gunny:client:syncAmmo', source, 0) end
            return
        end
        before = meta.magazine.ammo or 0
        newAmmo = math.max(0, before - shotsFired)
        meta.magazine.ammo = newAmmo
    end

    -- A failed write: the round was never spent. `quiet`: no whole-inventory push every shot (the count goes back as
    -- syncAmmo); the pockets are saved about once a second, so a burst is one write.
    if not exports.whip_core:SetItemMetadata(addr, meta, { quiet = true }) then
        GunnyWarn('shot fired but metadata write FAILED — ammo not synced to client')
        return
    end

    GunnyDebugPrint(late and 'Shot fired as the gun went away - Ammo:' or 'Shot fired - Ammo:', newAmmo)
    if weaponConfig.magless then
        GunnyLedgerGun(source, slotData.item, equipped.serial, 'shot', before, newAmmo, shotsFired)   -- server/ledger.lua
    end
    if not late then TriggerClientEvent('whip_gunny:client:syncAmmo', source, newAmmo) end
    -- Only rounds there were: a claim past an empty gun spent nothing.
    if before > newAmmo then fired(source, slotData, equipped, before - newAmmo, newAmmo) end
end)

--- The client's own count, every few seconds: taken only when lower (a shot the server missed). Higher would be a
--- free reload. One from before the server's last change to the gun (GunnyCountChanged) is ignored: it was counted
--- for the magazine that was in it then. One sent as the gun went away counts for it, as a shot does (the top of this
--- file).
RegisterGunnyEvent('whip_gunny:server:syncAmmo', {
    whileDead = true,
    -- About once a second at most (the jerry can's pour sends its level each second by the client's clock), with a
    -- burst: one arriving a few ms early over a jittery connection is still taken, not refused.
    rateLimit = 1000,
    burst     = 3,
    params = {
        {'ammoCount',    'int', 0, 9999},
        {'countVersion', 'int', 0, 2147483647, 0},
    },
}, function(source, _, ammoCount, countVersion)
    local slotData, equipped, late = GunnyDrawnWeapon(source, true)
    if not equipped then GunnyNoDrawRecord(source) return end
    if not slotData then
        if not late then GunnyForceHolster(source) end
        return
    end
    if countVersion ~= equipped.countVersion then
        GunnyDebugPrint('Ammo sync from before the last change ignored', source, countVersion, equipped.countVersion)
        return
    end
    local addr = GunnyPocket(source, equipped.pocket, equipped.slot)

    local weaponConfig = Config.GetWeapon(slotData.item)
    if not weaponConfig then return end

    -- The jerry can: its count is GTA's petrol, and what is left becomes its level (down only).
    if Config.IsFuelCan(weaponConfig) then
        GunnySyncFuelCan(source, slotData, equipped, ammoCount)
        return
    end

    local meta = slotData.metadata or {}
    local before

    if weaponConfig.magless then
        before = meta.ammo or 0
        if ammoCount >= before then return end
        meta.ammo = ammoCount
    else
        if not meta.magazine then return end
        before = meta.magazine.ammo or 0
        if ammoCount >= before then return end
        meta.magazine.ammo = ammoCount
    end

    if not exports.whip_core:SetItemMetadata(addr, meta, { quiet = true }) then
        GunnyWarn('ammo sync metadata write FAILED')
        return
    end
    GunnyDebugPrint('Synced ammo from client:', ammoCount)
    if weaponConfig.magless then
        GunnyLedgerGun(source, slotData.item, equipped.serial, 'sync', before, ammoCount)   -- server/ledger.lua
    end
    fired(source, slotData, equipped, before - ammoCount, ammoCount)
end)
