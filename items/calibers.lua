-- whip_gunny — CALIBERS: the ammunition items
--
-- One entry per kind of round. Each is an item of its own (`ammoItem`): a stack of loose rounds that loads into
-- the magazines and guns of that caliber. A weapon's or a magazine's `caliber` names one of these.
--   ammoItem    the item's key
--   ammoWeight  one round, in kg (0.01 if not given)
--   label       the item is called "<label> Round"
--   prop        a dropped box of them (gunny's own ammo boxes, stream/whip_ammobox_*)

Config.Calibers = {
    ['9mm'] = {
        ammoItem = 'ammo_9mm',
        ammoWeight = 0.007,
        label = '9mm',
        prop = 'whip_ammobox_9mm',
    },
    ['.45 ACP'] = {
        ammoItem = 'ammo_45acp',
        ammoWeight = 0.014,
        label = '.45 ACP',
        prop = 'whip_ammobox_45acp',
    },
    ['.50 AE'] = {
        ammoItem = 'ammo_50ae',
        ammoWeight = 0.022,
        label = '.50 AE',
        prop = 'whip_ammobox_50ae',
    },
    ['5.56x45'] = {
        ammoItem = 'ammo_556',
        ammoWeight = 0.012,
        label = '5.56x45',
        prop = 'whip_ammobox_556',
    },
    ['7.62x39'] = {
        ammoItem = 'ammo_762x39',
        ammoWeight = 0.016,
        label = '7.62x39',
        prop = 'whip_ammobox_762x39',
    },
    ['7.62x51'] = {
        ammoItem = 'ammo_762x51',
        ammoWeight = 0.025,
        label = '7.62x51',
        prop = 'whip_ammobox_762x51',
    },
    ['.308 Win'] = {
        ammoItem = 'ammo_308',
        ammoWeight = 0.025,
        label = '.308 Win',
        prop = 'whip_ammobox_308',
    },
    ['.50 BMG'] = {
        ammoItem = 'ammo_50bmg',
        ammoWeight = 0.115,
        label = '.50 BMG',
        prop = 'whip_ammobox_50bmg',
    },
    ['12 Gauge'] = {
        ammoItem = 'ammo_12gauge',
        ammoWeight = 0.040,
        label = '12 Gauge',
        prop = 'whip_ammobox_12gauge',
    },
    ['.357 Magnum'] = {
        ammoItem = 'ammo_357',
        ammoWeight = 0.016,
        label = '.357 Magnum',
        prop = 'whip_ammobox_357',
    },
    ['.44 Magnum'] = {
        ammoItem = 'ammo_44mag',
        ammoWeight = 0.025,
        label = '.44 Magnum',
        prop = 'whip_ammobox_44mag',
    },
    ['.36 Navy'] = {
        ammoItem = 'ammo_36navy',
        ammoWeight = 0.008,
        label = '.36 Navy',
        prop = 'whip_ammobox_36navy',
    },
    ['.22 LR'] = {
        ammoItem = 'ammo_22lr',
        ammoWeight = 0.003,
        label = '.22 LR',
        prop = 'whip_ammobox_22lr',
    },
    ['Musket Ball'] = {
        ammoItem = 'ammo_musket',
        ammoWeight = 0.035,
        label = 'Musket Ball',
        prop = 'whip_ammobox_musket',
    },
    ['Flare'] = {
        ammoItem = 'ammo_flare',
        ammoWeight = 0.06,
        label = 'Flare',
        prop = 'whip_ammobox_flare',
    },
    ['Taser Cartridge'] = {
        ammoItem = 'ammo_taser',
        ammoWeight = 0.03,
        label = 'Taser Cartridge',
        prop = 'whip_ammobox_taser',
    },
    ['Energy Cell'] = {
        ammoItem = 'ammo_energycell',
        ammoWeight = 0.01,   -- light: the Widowmaker holds 9,999
        label = 'Energy Cell',
        prop = 'whip_ammobox_energycell',
    },
    ['Railgun Slug'] = {
        ammoItem = 'ammo_railgun',
        ammoWeight = 0.25,
        label = 'Railgun Slug',
        prop = 'whip_ammobox_railgun',
    },
    ['Rocket'] = {
        ammoItem = 'ammo_rocket',
        ammoWeight = 2.2,
        label = 'Rocket',
        prop = 'whip_ammobox_rocket',   -- a 1.15 m wooden crate, open
    },
    ['Homing Rocket'] = {
        ammoItem = 'ammo_homingrocket',
        ammoWeight = 3.0,
        label = 'Homing Rocket',
        prop = 'whip_ammobox_homingrocket',   -- a 1.02 m case, open
    },
    ['40mm Grenade'] = {
        ammoItem = 'ammo_40mm',
        ammoWeight = 0.23,
        label = '40mm Grenade',
        prop = 'whip_ammobox_40mm',
    },
    ['Firework'] = {
        ammoItem = 'ammo_firework',
        ammoWeight = 0.5,
        label = 'Firework',
        prop = 'whip_ammobox_firework',   -- a 59 cm pack, open (96 cm with its rockets)
    },
    ['Minigun Round'] = {
        ammoItem = 'ammo_minigun',
        ammoWeight = 0.025,   -- a 7.62 round, as the 7.62x51
        label = 'Minigun Round',
        prop = 'whip_ammobox_minigun',   -- a 39 cm steel can, open
    },
    ['EMP Round'] = {
        ammoItem = 'ammo_emp',
        ammoWeight = 0.25,
        label = 'EMP Round',
        prop = 'whip_ammobox_emp',
    },
}
