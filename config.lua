-- whip_gunny — SETTINGS
--
-- The items gunny adds are in items/: calibers.lua, weapons.lua, magazines.lua and attachments.lua. A magazine's size
-- and a gun's reload time and rounds are also set per item on /whip's Items page.

Config = {}

-- The weapon bench, where attachments go on and come off: E at it with a gun in hand. enabled = false: no bench.
-- coords is x, y, z and heading.
Config.WeaponBench = {
    enabled = true,
    coords  = vector4(-1069.5194, -1666.3589, 3.3856, 302.7092),
    model   = `gr_prop_gr_bench_04b`,
    label   = 'Weapon Bench',
}
