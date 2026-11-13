-- whip_gunny — THROWABLES (client)
--
-- A throwable is a stack, and the hand holds the whole stack. GTA throws, cooks and sets them off; gunny only counts:
-- a throw shows as GTA's count going down, and how many left the hand goes to the server, which takes them from the
-- stack (server/throwables.lua). Looked at every frame one is drawn, and once more as it is put away, so a throw just
-- before a holster or a death still counts. G (LB + B on a controller) sets off the player's sticky bombs.

local STICKY = `WEAPON_STICKYBOMB`
-- How far G reaches. GTA keeps no list of a player's sticky bombs, so it is a radius wide enough for anywhere they
-- could have thrown one and still be.
local DETONATE_RANGE = 2000.0

--- Is the drawn weapon a throwable?
---@return boolean
function GunnyThrowableDrawn()
    return CurrentWeapon ~= nil and Config.IsThrowable(CurrentWeapon.config)
end

--- What left the hand since the last look, told to the server (at most 10 a report, as its schema allows). A count
--- that went up is not believed: the server's count comes back as whip_gunny:client:syncThrown.
---
--- GTA takes the weapon away with the last one thrown: gone with one left, it was thrown; gone with more, something
--- else took it, and nothing was thrown.
---@param ped number
function GunnyThrowSettle(ped)
    if not GunnyThrowableDrawn() then return end
    local known = CurrentWeapon.ammo or 0
    local left
    if HasPedGotWeapon(ped, CurrentWeapon.hash, false) then
        left = GetAmmoInPedWeapon(ped, CurrentWeapon.hash)
    elseif known == 1 then
        left = 0
    else
        return
    end
    if left >= known then return end
    CurrentWeapon.ammo = left
    local n = known - left
    while n > 0 do
        local part = math.min(n, 10)
        TriggerServerEvent('whip_gunny:server:thrown', part)
        CurrentWeapon.thrownSent = (CurrentWeapon.thrownSent or 0) + part   -- every throw reported this draw
        n = n - part
    end
    GunnyDebugPrint('Threw', known - left, CurrentWeapon.name, '-', left, 'left')
end

-- The drawn stack's count from the server: it changed in the inventory while drawn, or a throw could not be taken.
-- `taken` is how many of this draw's throws the server has had; the ones reported and not had yet are still in its
-- count, so they come off it here instead of coming back to the hand.
RegisterNetEvent('whip_gunny:client:syncThrown', function(count, taken)
    -- During a draw: kept, and applied as the draw ends (client/weapons.lua, GunnyDrawNote)
    if not GunnyThrowableDrawn() then
        GunnyDrawNote('count', math.max(0, math.floor(tonumber(count) or 0)))
        return
    end
    GunnyThrowSettle(PlayerPedId())
    count = math.max(0, math.floor(tonumber(count) or 0))
    local inFlight = math.max(0, (CurrentWeapon.thrownSent or 0) - math.floor(tonumber(taken) or 0))
    GunnyAmmo.setStack(count - inFlight)
end)

--- G: set off the player's sticky bombs. true when there were some out; false when none (G checks the ammo instead).
---@return boolean
function GunnyDetonateStickyBombs()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    if not IsProjectileTypeWithinDistance(pos.x, pos.y, pos.z, STICKY, DETONATE_RANGE, true) then return false end
    ExplodeProjectiles(ped, STICKY, true)
    return true
end
