-- whip_gunny — THROWABLES (server)
--
-- Each one thrown is taken from the drawn stack through whip_core, which logs it ("thrown"). Only ever taken, never
-- given: a client can lose its own grenades by saying so, never gain one. Each report is bounded and capped at the
-- stack.

RegisterGunnyEvent('whip_gunny:server:thrown', {
    whileDead = true,   -- one thrown (or a cooked one dropped) as the player dies still leaves the stack
    sheet = 'light',    -- the handler never reads `player`
    -- A throw takes most of a second; the burst covers a few reported together after a hitch.
    rateLimit = 100,
    burst     = 5,
    params = {
        {'count', 'int', 1, 10, 1},
    },
}, function(source, _, count)
    local slotData, equipped = GunnyDrawnWeapon(source)
    if not equipped then GunnyNoDrawRecord(source) return end
    if not slotData then
        GunnyForceHolster(source)
        return
    end
    if not Config.IsThrowable(Config.GetWeapon(slotData.item)) then return end

    -- Every throw reported this draw, sent back with each stack count so the client takes off those still on their way
    equipped.taken = (equipped.taken or 0) + count

    local have = tonumber(slotData.amount) or 0
    count = math.min(count, have)
    if count < 1 then return end

    -- The stack as the hand has it now, first: our own take must arrive as no change (server/weapons.lua).
    equipped.count = have - count
    local addr = GunnyPocket(source, equipped.pocket, equipped.slot)
    local removed, why = exports.whip_core:StoreTake(addr, count, 'thrown')
    if not removed then
        equipped.count = have
        GunnyWarn('a throw was not taken from the stack (%s): %s', slotData.item, tostring(why))
        TriggerClientEvent('whip_gunny:client:syncThrown', source, have, equipped.taken)   -- the hand back to the stack's count
        return
    end
    GunnyDebugPrint('Thrown:', count, slotData.item, '-', equipped.count, 'left')
end)
