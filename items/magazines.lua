-- whip_gunny — MAGAZINES: one entry per magazine item, keyed by the item
--
--   weight, label   the item: kg (0.3 if not given), its name
--   prop            its model lying on the ground
--   caliber         the rounds it takes (items/calibers.lua)
--   capacity        how many (also a per-item setting on /whip's Items page)
--   component       the GTA magazine it shows on the gun; none is the gun's own (its defaultClipComponent)
-- Which guns take it is each gun's `compatibleMags` (items/weapons.lua).

Config.Magazines = {
    -- ========== PISTOL MAGAZINES ==========

    -- Pistol (12/16)
    ['gunny_mag_pistol'] = {
        weight = 0.15,
        label = 'Pistol Magazine',
        prop = 'w_pi_pistol_mag1',
        caliber = '9mm',
        capacity = 12,
    },
    ['gunny_mag_pistol_extended'] = {
        weight = 0.2,
        label = 'Pistol 16 Round Magazine',
        prop = 'w_pi_pistol_mag2',
        caliber = '9mm',
        capacity = 16,
        component = `COMPONENT_PISTOL_CLIP_02`,
    },

    -- Pistol Mk II (12/16)
    ['gunny_mag_pistol_mk2'] = {
        weight = 0.15,
        label = 'Pistol Mk II Magazine',
        prop = 'w_pi_pistolmk2_mag1',
        caliber = '9mm',
        capacity = 12,
    },
    ['gunny_mag_pistol_mk2_extended'] = {
        weight = 0.2,
        label = 'Pistol Mk II 16 Round Magazine',
        prop = 'w_pi_pistolmk2_mag2',
        caliber = '9mm',
        capacity = 16,
        component = `COMPONENT_PISTOL_MK2_CLIP_02`,
    },

    -- Combat Pistol (12/16)
    ['gunny_mag_combatpistol'] = {
        weight = 0.15,
        label = 'Combat Pistol Magazine',
        prop = 'w_pi_combatpistol_mag1',
        caliber = '9mm',
        capacity = 12,
    },
    ['gunny_mag_combatpistol_extended'] = {
        weight = 0.2,
        label = 'Combat Pistol 16 Round Magazine',
        prop = 'w_pi_combatpistol_mag2',
        caliber = '9mm',
        capacity = 16,
        component = `COMPONENT_COMBATPISTOL_CLIP_02`,
    },

    -- AP Pistol (18/36)
    ['gunny_mag_appistol'] = {
        weight = 0.18,
        label = 'AP Pistol Magazine',
        prop = 'w_pi_appistol_mag1',
        caliber = '9mm',
        capacity = 18,
    },
    ['gunny_mag_appistol_extended'] = {
        weight = 0.28,
        label = 'AP Pistol 36 Round Magazine',
        prop = 'w_pi_appistol_mag2',
        caliber = '9mm',
        capacity = 36,
        component = `COMPONENT_APPISTOL_CLIP_02`,
    },

    -- Pistol .50 (9/12)
    ['gunny_mag_pistol50'] = {
        weight = 0.2,
        label = 'Pistol .50 Magazine',
        prop = 'w_pi_pistol50_mag1',
        caliber = '.50 AE',
        capacity = 9,
    },
    ['gunny_mag_pistol50_extended'] = {
        weight = 0.25,
        label = 'Pistol .50 12 Round Magazine',
        prop = 'w_pi_pistol50_mag2',
        caliber = '.50 AE',
        capacity = 12,
        component = `COMPONENT_PISTOL50_CLIP_02`,
    },

    -- SNS Pistol (6/12)
    ['gunny_mag_snspistol'] = {
        weight = 0.08,
        label = 'SNS Pistol Magazine',
        prop = 'w_pi_sns_pistol_mag1',
        caliber = '9mm',
        capacity = 6,
    },
    ['gunny_mag_snspistol_extended'] = {
        weight = 0.12,
        label = 'SNS Pistol 12 Round Magazine',
        prop = 'w_pi_sns_pistol_mag2',
        caliber = '9mm',
        capacity = 12,
        component = `COMPONENT_SNSPISTOL_CLIP_02`,
    },

    -- SNS Pistol Mk II (6/12)
    ['gunny_mag_snspistol_mk2'] = {
        weight = 0.08,
        label = 'SNS Pistol Mk II Magazine',
        prop = 'w_pi_sns_pistolmk2_mag1',
        caliber = '9mm',
        capacity = 6,
    },
    ['gunny_mag_snspistol_mk2_extended'] = {
        weight = 0.12,
        label = 'SNS Pistol Mk II 12 Round Magazine',
        prop = 'w_pi_sns_pistolmk2_mag2',
        caliber = '9mm',
        capacity = 12,
        component = `COMPONENT_SNSPISTOL_MK2_CLIP_02`,
    },

    -- Heavy Pistol (18/36)
    ['gunny_mag_heavypistol'] = {
        weight = 0.2,
        label = 'Heavy Pistol Magazine',
        prop = 'w_pi_whip_heavypistol_mag1',
        caliber = '.45 ACP',
        capacity = 18,
    },
    ['gunny_mag_heavypistol_extended'] = {
        weight = 0.32,
        label = 'Heavy Pistol 36 Round Magazine',
        prop = 'w_pi_whip_heavypistol_mag2',
        caliber = '.45 ACP',
        capacity = 36,
        component = `COMPONENT_WHIP_HEAVYPISTOL_CLIP_02`,
    },

    -- Vintage Pistol (7/12)
    ['gunny_mag_vintagepistol'] = {
        weight = 0.1,
        label = 'Vintage Pistol Magazine',
        prop = 'w_pi_vintage_pistol_mag1',
        caliber = '9mm',
        capacity = 7,
    },
    ['gunny_mag_vintagepistol_extended'] = {
        weight = 0.15,
        label = 'Vintage Pistol 12 Round Magazine',
        prop = 'w_pi_vintage_pistol_mag2',
        caliber = '9mm',
        capacity = 12,
        component = `COMPONENT_VINTAGEPISTOL_CLIP_02`,
    },

    -- Ceramic Pistol (12/17)
    ['gunny_mag_ceramicpistol'] = {
        weight = 0.1,
        label = 'Ceramic Pistol Magazine',
        prop = 'w_pi_ceramic_mag1',
        caliber = '9mm',
        capacity = 12,
    },
    ['gunny_mag_ceramicpistol_extended'] = {
        weight = 0.14,
        label = 'Ceramic Pistol 17 Round Magazine',
        prop = 'w_pi_sns_pistol_mag2',
        caliber = '9mm',
        capacity = 17,
        component = `COMPONENT_CERAMICPISTOL_CLIP_02`,
    },

    -- Perico Pistol (12)
    ['gunny_mag_gadgetpistol'] = {
        weight = 0.1,
        label = 'Perico Pistol Magazine',
        prop = 'w_pi_singleshoth4_shell',
        caliber = '9mm',
        capacity = 12,
    },

    -- ========== SMG MAGAZINES ==========

    -- SMG (30/60)
    ['gunny_mag_smg'] = {
        weight = 0.2,
        label = 'SMG Magazine',
        prop = 'w_sb_smg_mag1',
        caliber = '9mm',
        capacity = 30,
    },
    ['gunny_mag_smg_extended'] = {
        weight = 0.35,
        label = 'SMG 60 Round Magazine',
        prop = 'w_sb_smg_mag2',
        caliber = '9mm',
        capacity = 60,
        component = `COMPONENT_SMG_CLIP_02`,
    },
    ['gunny_mag_smg_drum'] = {
        weight = 0.6,
        label = 'SMG 100 Round Magazine',
        prop = 'w_sb_smg_boxmag',
        caliber = '9mm',
        capacity = 100,
        component = `COMPONENT_SMG_CLIP_03`,
    },

    -- SMG Mk II (30/60)
    ['gunny_mag_smg_mk2'] = {
        weight = 0.2,
        label = 'SMG Mk II Magazine',
        prop = 'w_sb_smgmk2_mag1',
        caliber = '9mm',
        capacity = 30,
    },
    ['gunny_mag_smg_mk2_extended'] = {
        weight = 0.35,
        label = 'SMG Mk II 60 Round Magazine',
        prop = 'w_sb_smgmk2_mag2',
        caliber = '9mm',
        capacity = 60,
        component = `COMPONENT_SMG_MK2_CLIP_02`,
    },

    -- Micro SMG (16/30)
    ['gunny_mag_microsmg'] = {
        weight = 0.12,
        label = 'Micro SMG Magazine',
        prop = 'w_sb_microsmg_mag1',
        caliber = '9mm',
        capacity = 16,
    },
    ['gunny_mag_microsmg_extended'] = {
        weight = 0.2,
        label = 'Micro SMG 30 Round Magazine',
        prop = 'w_sb_microsmg_mag2',
        caliber = '9mm',
        capacity = 30,
        component = `COMPONENT_MICROSMG_CLIP_02`,
    },

    -- Mini SMG (20/30)
    ['gunny_mag_minismg'] = {
        weight = 0.14,
        label = 'Mini SMG Magazine',
        prop = 'w_sb_minismg_mag1',
        caliber = '9mm',
        capacity = 20,
    },
    ['gunny_mag_minismg_extended'] = {
        weight = 0.2,
        label = 'Mini SMG 30 Round Magazine',
        prop = 'w_sb_minismg_mag2',
        caliber = '9mm',
        capacity = 30,
        component = `COMPONENT_MINISMG_CLIP_02`,
    },

    -- Assault SMG (30/60)
    ['gunny_mag_assaultsmg'] = {
        weight = 0.2,
        label = 'Assault SMG Magazine',
        prop = 'w_sb_assaultsmg_mag1',
        caliber = '9mm',
        capacity = 30,
    },
    ['gunny_mag_assaultsmg_extended'] = {
        weight = 0.35,
        label = 'Assault SMG 60 Round Magazine',
        prop = 'w_sb_assaultsmg_mag2',
        caliber = '9mm',
        capacity = 60,
        component = `COMPONENT_ASSAULTSMG_CLIP_02`,
    },

    -- Combat PDW (30/60)
    ['gunny_mag_combatpdw'] = {
        weight = 0.2,
        label = 'Combat PDW Magazine',
        prop = 'w_sb_pdw_mag1',
        caliber = '9mm',
        capacity = 30,
    },
    ['gunny_mag_combatpdw_extended'] = {
        weight = 0.35,
        label = 'Combat PDW 60 Round Magazine',
        prop = 'w_sb_pdw_mag2',
        caliber = '9mm',
        capacity = 60,
        component = `COMPONENT_COMBATPDW_CLIP_02`,
    },
    ['gunny_mag_combatpdw_drum'] = {
        weight = 0.6,
        label = 'Combat PDW 100 Round Magazine',
        prop = 'w_sb_pdw_boxmag',
        caliber = '9mm',
        capacity = 100,
        component = `COMPONENT_COMBATPDW_CLIP_03`,
    },

    -- Machine Pistol (12/30/60)
    ['gunny_mag_machinepistol'] = {
        weight = 0.1,
        label = 'Machine Pistol Magazine',
        prop = 'w_sb_compactsmg_mag1',
        caliber = '9mm',
        capacity = 12,
    },
    ['gunny_mag_machinepistol_extended'] = {
        weight = 0.2,
        label = 'Machine Pistol 30 Round Magazine',
        prop = 'w_sb_compactsmg_mag2',
        caliber = '9mm',
        capacity = 30,
        component = `COMPONENT_MACHINEPISTOL_CLIP_02`,
    },
    ['gunny_mag_machinepistol_drum'] = {
        weight = 0.4,
        label = 'Machine Pistol 60 Round Magazine',
        prop = 'w_sb_compactsmg_boxmag',
        caliber = '9mm',
        capacity = 60,
        component = `COMPONENT_MACHINEPISTOL_CLIP_03`,
    },

    -- Tactical SMG (17/33)
    ['gunny_mag_tecpistol'] = {
        weight = 0.12,
        label = 'Tactical SMG Magazine',
        prop = 'w_pi_pistolsmg_m31_mag1',
        caliber = '9mm',
        capacity = 17,
    },
    ['gunny_mag_tecpistol_extended'] = {
        weight = 0.2,
        label = 'Tactical SMG 33 Round Magazine',
        prop = 'w_pi_pistolsmg_m31_mag2',
        caliber = '9mm',
        capacity = 33,
        component = `COMPONENT_TECPISTOL_CLIP_02`,
    },

    -- ========== ASSAULT RIFLE MAGAZINES ==========

    -- Assault Rifle (30/60)
    ['gunny_mag_rifle'] = {
        weight = 0.3,
        label = 'Assault Rifle Magazine',
        prop = 'w_ar_whip_assaultrifle_mag1',
        caliber = '5.56x45',
        capacity = 30,
    },
    ['gunny_mag_rifle_extended'] = {
        weight = 0.5,
        label = 'Assault Rifle 60 Round Magazine',
        prop = 'w_ar_whip_assaultrifle_mag2',
        caliber = '5.56x45',
        capacity = 60,
        component = `COMPONENT_WHIP_ASSAULTRIFLE_CLIP_02`,
    },
    ['gunny_mag_rifle_drum'] = {
        weight = 0.7,
        label = 'Assault Rifle 100 Round Magazine',
        prop = 'w_ar_assaultrifle_boxmag',
        caliber = '5.56x45',
        capacity = 100,
        component = `COMPONENT_ASSAULTRIFLE_CLIP_03`,
    },

    -- Assault Rifle Mk II (30/60)
    ['gunny_mag_rifle_mk2'] = {
        weight = 0.3,
        label = 'Assault Rifle Mk II Magazine',
        prop = 'w_ar_assaultriflemk2_mag1',
        caliber = '5.56x45',
        capacity = 30,
    },
    ['gunny_mag_rifle_mk2_extended'] = {
        weight = 0.5,
        label = 'Assault Rifle Mk II 60 Round Magazine',
        prop = 'w_ar_assaultriflemk2_mag2',
        caliber = '5.56x45',
        capacity = 60,
        component = `COMPONENT_ASSAULTRIFLE_MK2_CLIP_02`,
    },

    -- Carbine Rifle (30/60)
    ['gunny_mag_carbinerifle'] = {
        weight = 0.3,
        label = 'Carbine Rifle Magazine',
        prop = 'w_ar_carbinerifle_mag1',
        caliber = '5.56x45',
        capacity = 30,
    },
    ['gunny_mag_carbinerifle_extended'] = {
        weight = 0.5,
        label = 'Carbine Rifle 60 Round Magazine',
        prop = 'w_ar_carbinerifle_mag2',
        caliber = '5.56x45',
        capacity = 60,
        component = `COMPONENT_CARBINERIFLE_CLIP_02`,
    },
    ['gunny_mag_carbinerifle_drum'] = {
        weight = 0.7,
        label = 'Carbine Rifle 100 Round Magazine',
        prop = 'w_ar_carbinerifle_boxmag',
        caliber = '5.56x45',
        capacity = 100,
        component = `COMPONENT_CARBINERIFLE_CLIP_03`,
    },

    -- Carbine Rifle Mk II (30/60)
    ['gunny_mag_carbinerifle_mk2'] = {
        weight = 0.3,
        label = 'Carbine Rifle Mk II Magazine',
        prop = 'w_ar_carbineriflemk2_mag1',
        caliber = '5.56x45',
        capacity = 30,
    },
    ['gunny_mag_carbinerifle_mk2_extended'] = {
        weight = 0.5,
        label = 'Carbine Rifle Mk II 60 Round Magazine',
        prop = 'w_ar_carbineriflemk2_mag2',
        caliber = '5.56x45',
        capacity = 60,
        component = `COMPONENT_CARBINERIFLE_MK2_CLIP_02`,
    },

    -- Advanced Rifle (30/60)
    ['gunny_mag_advancedrifle'] = {
        weight = 0.3,
        label = 'Advanced Rifle Magazine',
        prop = 'w_ar_advancedrifle_mag1',
        caliber = '5.56x45',
        capacity = 30,
    },
    ['gunny_mag_advancedrifle_extended'] = {
        weight = 0.5,
        label = 'Advanced Rifle 60 Round Magazine',
        prop = 'w_ar_advancedrifle_mag2',
        caliber = '5.56x45',
        capacity = 60,
        component = `COMPONENT_ADVANCEDRIFLE_CLIP_02`,
    },

    -- Special Carbine (30/60)
    ['gunny_mag_specialcarbine'] = {
        weight = 0.3,
        label = 'Special Carbine Magazine',
        prop = 'w_ar_specialcarbine_mag1',
        caliber = '5.56x45',
        capacity = 30,
    },
    ['gunny_mag_specialcarbine_extended'] = {
        weight = 0.5,
        label = 'Special Carbine 60 Round Magazine',
        prop = 'w_ar_specialcarbine_mag2',
        caliber = '5.56x45',
        capacity = 60,
        component = `COMPONENT_SPECIALCARBINE_CLIP_02`,
    },
    ['gunny_mag_specialcarbine_drum'] = {
        weight = 0.7,
        label = 'Special Carbine 100 Round Magazine',
        prop = 'w_ar_specialcarbine_boxmag',
        caliber = '5.56x45',
        capacity = 100,
        component = `COMPONENT_SPECIALCARBINE_CLIP_03`,
    },

    -- Special Carbine Mk II (30/60)
    ['gunny_mag_specialcarbine_mk2'] = {
        weight = 0.3,
        label = 'Special Carbine Mk II Magazine',
        prop = 'w_ar_specialcarbinemk2_mag1',
        caliber = '5.56x45',
        capacity = 30,
    },
    ['gunny_mag_specialcarbine_mk2_extended'] = {
        weight = 0.5,
        label = 'Special Carbine Mk II 60 Round Magazine',
        prop = 'w_ar_specialcarbinemk2_mag2',
        caliber = '5.56x45',
        capacity = 60,
        component = `COMPONENT_SPECIALCARBINE_MK2_CLIP_02`,
    },

    -- Bullpup Rifle (30/60)
    ['gunny_mag_bullpuprifle'] = {
        weight = 0.3,
        label = 'Bullpup Rifle Magazine',
        prop = 'w_ar_bullpuprifle_mag1',
        caliber = '5.56x45',
        capacity = 30,
    },
    ['gunny_mag_bullpuprifle_extended'] = {
        weight = 0.5,
        label = 'Bullpup Rifle 60 Round Magazine',
        prop = 'w_ar_bullpuprifle_mag2',
        caliber = '5.56x45',
        capacity = 60,
        component = `COMPONENT_BULLPUPRIFLE_CLIP_02`,
    },

    -- Bullpup Rifle Mk II (30/60)
    ['gunny_mag_bullpuprifle_mk2'] = {
        weight = 0.3,
        label = 'Bullpup Rifle Mk II Magazine',
        prop = 'w_ar_bullpupriflemk2_mag1',
        caliber = '5.56x45',
        capacity = 30,
    },
    ['gunny_mag_bullpuprifle_mk2_extended'] = {
        weight = 0.5,
        label = 'Bullpup Rifle Mk II 60 Round Magazine',
        prop = 'w_ar_bullpupriflemk2_mag2',
        caliber = '5.56x45',
        capacity = 60,
        component = `COMPONENT_BULLPUPRIFLE_MK2_CLIP_02`,
    },

    -- Compact Rifle (30/60)
    ['gunny_mag_compactrifle'] = {
        weight = 0.35,
        label = 'Compact Rifle Magazine',
        prop = 'w_ar_assaultrifle_smg_mag1',
        caliber = '7.62x39',
        capacity = 30,
    },
    ['gunny_mag_compactrifle_extended'] = {
        weight = 0.55,
        label = 'Compact Rifle 60 Round Magazine',
        prop = 'w_ar_assaultrifle_smg_mag2',
        caliber = '7.62x39',
        capacity = 60,
        component = `COMPONENT_COMPACTRIFLE_CLIP_02`,
    },
    ['gunny_mag_compactrifle_drum'] = {
        weight = 0.7,
        label = 'Compact Rifle 100 Round Magazine',
        prop = 'w_ar_assaultrifle_boxmag',
        caliber = '7.62x39',
        capacity = 100,
        component = `COMPONENT_COMPACTRIFLE_CLIP_03`,
    },

    -- Military Rifle (30/50)
    ['gunny_mag_militaryrifle'] = {
        weight = 0.3,
        label = 'Military Rifle Magazine',
        prop = 'w_ar_bullpuprifleh4_mag1',
        caliber = '5.56x45',
        capacity = 30,
    },
    ['gunny_mag_militaryrifle_extended'] = {
        weight = 0.45,
        label = 'Military Rifle 50 Round Magazine',
        prop = 'w_ar_bullpuprifleh4_mag2',
        caliber = '5.56x45',
        capacity = 50,
        component = `COMPONENT_MILITARYRIFLE_CLIP_02`,
    },

    -- Heavy Rifle (30/60)
    ['gunny_mag_heavyrifle'] = {
        weight = 0.4,
        label = 'Heavy Rifle Magazine',
        prop = 'w_ar_specialcarbine_mag1',
        caliber = '7.62x51',
        capacity = 30,
    },
    ['gunny_mag_heavyrifle_extended'] = {
        weight = 0.65,
        label = 'Heavy Rifle 60 Round Magazine',
        prop = 'w_ar_specialcarbine_mag2',
        caliber = '7.62x51',
        capacity = 60,
        component = `COMPONENT_HEAVYRIFLE_CLIP_02`,
    },

    -- Service Carbine/Tactical Rifle (30/60)
    ['gunny_mag_tacticalrifle'] = {
        weight = 0.3,
        label = 'Service Carbine Magazine',
        prop = 'w_ar_carbinerifle_mag1',
        caliber = '5.56x45',
        capacity = 30,
    },
    ['gunny_mag_tacticalrifle_extended'] = {
        weight = 0.5,
        label = 'Service Carbine 60 Round Magazine',
        prop = 'w_ar_carbinerifle_mag2',
        caliber = '5.56x45',
        capacity = 60,
        component = `COMPONENT_TACTICALRIFLE_CLIP_02`,
    },

    -- Battle Rifle (20/30)
    ['gunny_mag_battlerifle'] = {
        weight = 0.27,
        label = 'Battle Rifle Magazine',
        prop = 'w_sl_battlerifle_m32_mag1',
        caliber = '7.62x51',
        capacity = 20,
    },
    ['gunny_mag_battlerifle_extended'] = {
        weight = 0.4,
        label = 'Battle Rifle 30 Round Magazine',
        prop = 'w_sl_battlerifle_m32_mag2',
        caliber = '7.62x51',
        capacity = 30,
        component = `COMPONENT_BATTLERIFLE_CLIP_02`,
    },

    -- ========== LMG MAGAZINES ==========

    -- MG (54/100)
    ['gunny_mag_mg'] = {
        weight = 0.8,
        label = 'MG Box Magazine',
        prop = 'w_mg_mg_mag1',
        caliber = '7.62x51',
        capacity = 54,
    },
    ['gunny_mag_mg_extended'] = {
        weight = 1.2,
        label = 'MG 100 Round Box Magazine',
        prop = 'w_mg_mg_mag2',
        caliber = '7.62x51',
        capacity = 100,
        component = `COMPONENT_MG_CLIP_02`,
    },

    -- Combat MG (100/200)
    ['gunny_mag_combatmg'] = {
        weight = 1.5,
        label = 'Combat MG Box Magazine',
        prop = 'w_mg_combatmg_mag1',
        caliber = '7.62x51',
        capacity = 100,
    },
    ['gunny_mag_combatmg_extended'] = {
        weight = 2.5,
        label = 'Combat MG 200 Round Box Magazine',
        prop = 'w_mg_combatmg_mag2',
        caliber = '7.62x51',
        capacity = 200,
        component = `COMPONENT_COMBATMG_CLIP_02`,
    },

    -- Combat MG Mk II (100/200)
    ['gunny_mag_combatmg_mk2'] = {
        weight = 1.5,
        label = 'Combat MG Mk II Box Magazine',
        prop = 'w_mg_combatmgmk2_mag1',
        caliber = '7.62x51',
        capacity = 100,
    },
    ['gunny_mag_combatmg_mk2_extended'] = {
        weight = 2.5,
        label = 'Combat MG Mk II 200 Round Box Magazine',
        prop = 'w_mg_combatmgmk2_mag2',
        caliber = '7.62x51',
        capacity = 200,
        component = `COMPONENT_COMBATMG_MK2_CLIP_02`,
    },

    -- Gusenberg Sweeper (30/50)
    ['gunny_mag_gusenberg'] = {
        weight = 0.4,
        label = 'Gusenberg Magazine',
        prop = 'w_sb_gusenberg_mag1',
        caliber = '.45 ACP',
        capacity = 30,
    },
    ['gunny_mag_gusenberg_extended'] = {
        weight = 0.6,
        label = 'Gusenberg 50 Round Magazine',
        prop = 'w_sb_gusenberg_mag2',
        caliber = '.45 ACP',
        capacity = 50,
        component = `COMPONENT_GUSENBERG_CLIP_02`,
    },

    -- ========== SNIPER RIFLE MAGAZINES ==========

    -- Sniper Rifle (10 only)
    ['gunny_mag_sniperrifle'] = {
        weight = 0.25,
        label = 'Sniper Rifle Magazine',
        prop = 'w_sr_sniperrifle_mag1',
        caliber = '.308 Win',
        capacity = 10,
    },

    -- Heavy Sniper (6 only)
    ['gunny_mag_heavysniper'] = {
        weight = 0.4,
        label = 'Heavy Sniper Magazine',
        prop = 'w_sr_heavysniper_mag1',
        caliber = '.50 BMG',
        capacity = 6,
    },

    -- Heavy Sniper Mk II (6/8)
    ['gunny_mag_heavysniper_mk2'] = {
        weight = 0.4,
        label = 'Heavy Sniper Mk II Magazine',
        prop = 'w_sr_heavysnipermk2_mag1',
        caliber = '.50 BMG',
        capacity = 6,
    },
    ['gunny_mag_heavysniper_mk2_extended'] = {
        weight = 0.5,
        label = 'Heavy Sniper Mk II 8 Round Magazine',
        prop = 'w_sr_heavysnipermk2_mag2',
        caliber = '.50 BMG',
        capacity = 8,
        component = `COMPONENT_HEAVYSNIPER_MK2_CLIP_02`,
    },

    -- Marksman Rifle (8/16)
    ['gunny_mag_marksmanrifle'] = {
        weight = 0.22,
        label = 'Marksman Rifle Magazine',
        prop = 'w_sr_marksmanrifle_mag1',
        caliber = '7.62x51',
        capacity = 8,
    },
    ['gunny_mag_marksmanrifle_extended'] = {
        weight = 0.35,
        label = 'Marksman Rifle 16 Round Magazine',
        prop = 'w_sr_marksmanrifle_mag2',
        caliber = '7.62x51',
        capacity = 16,
        component = `COMPONENT_MARKSMANRIFLE_CLIP_02`,
    },

    -- Marksman Rifle Mk II (8/16)
    ['gunny_mag_marksmanrifle_mk2'] = {
        weight = 0.22,
        label = 'Marksman Rifle Mk II Magazine',
        prop = 'w_sr_marksmanriflemk2_mag1',
        caliber = '7.62x51',
        capacity = 8,
    },
    ['gunny_mag_marksmanrifle_mk2_extended'] = {
        weight = 0.35,
        label = 'Marksman Rifle Mk II 16 Round Magazine',
        prop = 'w_sr_marksmanriflemk2_mag2',
        caliber = '7.62x51',
        capacity = 16,
        component = `COMPONENT_MARKSMANRIFLE_MK2_CLIP_02`,
    },

    -- Precision Rifle (6 only)
    ['gunny_mag_precisionrifle'] = {
        weight = 0.4,
        label = 'Precision Rifle Magazine',
        prop = 'w_sr_w_sr_precisionrifle_reh_mag1',   -- GTA's own spelling
        caliber = '.50 BMG',
        capacity = 6,
    },

    -- ========== SHOTGUN MAGAZINES ==========

    -- Assault Shotgun (8/32)
    ['gunny_mag_assaultshotgun'] = {
        weight = 0.3,
        label = 'Assault Shotgun Magazine',
        prop = 'w_sg_assaultshotgun_mag1',
        caliber = '12 Gauge',
        capacity = 8,
    },
    ['gunny_mag_assaultshotgun_extended'] = {
        weight = 0.8,
        label = 'Assault Shotgun 32 Round Magazine',
        prop = 'w_sg_assaultshotgun_mag2',
        caliber = '12 Gauge',
        capacity = 32,
        component = `COMPONENT_ASSAULTSHOTGUN_CLIP_02`,
    },

    -- Heavy Shotgun (6/12)
    ['gunny_mag_heavyshotgun'] = {
        weight = 0.25,
        label = 'Heavy Shotgun Magazine',
        prop = 'w_sg_heavyshotgun_mag1',
        caliber = '12 Gauge',
        capacity = 6,
    },
    ['gunny_mag_heavyshotgun_extended'] = {
        weight = 0.4,
        label = 'Heavy Shotgun 12 Round Magazine',
        prop = 'w_sg_heavyshotgun_mag2',
        caliber = '12 Gauge',
        capacity = 12,
        component = `COMPONENT_HEAVYSHOTGUN_CLIP_02`,
    },

    -- Sweeper Shotgun (10/32)
    ['gunny_mag_autoshotgun'] = {
        weight = 0.6,
        label = 'Sweeper Shotgun Drum',
        prop = 'w_sg_sweeper_mag1',
        caliber = '12 Gauge',
        capacity = 10,
    },
    ['gunny_mag_autoshotgun_extended'] = {
        weight = 0.9,
        label = 'Sweeper Shotgun 32 Round Drum',
        prop = 'w_sg_sweeper_mag1',
        caliber = '12 Gauge',
        capacity = 32,
        component = `COMPONENT_AUTOSHOTGUN_CLIP_02`,
    },
}
