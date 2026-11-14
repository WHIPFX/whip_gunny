-- whip_gunny — GUNNY DEBUG (server)
--
-- A player turning Gunny Debug on in /w (client/debug.lua) turns the server's GunnyDebugPrint lines on too, while
-- anyone has it on. /gunnydebugserver says what is drawn: everyone's at the console, your own in game.

RegisterGunnyEvent('whip_gunny:server:debug', {
    ace = 'whip.devtools',
    -- With a burst: turned off just after on, a refusal would leave the server printing for everyone.
    rateLimit = 500,
    burst     = 3,
    params = { { 'on', 'bool' } },
}, function(source, _, on)
    GunnyDebugFor[source] = on or nil
end)

AddEventHandler('playerDropped', function() GunnyDebugFor[source] = nil end)

-- The console, or a player with developer mode on (Whip.command's dev gate). A command runs whether whip_core is up or
-- not, so its calls go through Whip.core, which answers false instead of throwing (server/main.lua).
Whip.command('gunnydebugserver', { dev = true, whileDead = true }, function(source)
    if source == 0 then
        print('[GUNNY] drawn weapons:')
        for playerId, d in pairs(EquippedWeapons) do
            print(('  player %d: %s in slot %d (%s), serial %s'):format(playerId, d.weapon, d.slot, d.pocket, tostring(d.serial)))
        end
        return
    end
    local d = EquippedWeapons[source]
    Whip.core:NotifyPlayer(source, d and ('Drawn: %s in slot %d (%s), serial %s'):format(d.weapon, d.slot, d.pocket,
        tostring(d.serial)) or 'Nothing drawn', 'info')
end)
