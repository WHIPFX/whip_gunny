-- whip_gunny — ATTACHMENTS: the bench's slots, the attachment items, and which weapon takes which
--
--   Config.AttachmentCategories   the slots a gun can have: a label, and its icon on the bench page (html/script.js
--                                 ICONS)
--   Config.Attachments            one entry per attachment item: label, its slot (category), its kind (tier), prop;
--                                 weight in kg (0.2 if not given) and description, its card's text ("<label> weapon
--                                 attachment" if not given)
--   Config.WeaponAttachments      per weapon, per slot, per kind: the GTA component fitted. A weapon not listed takes
--                                 none. The kind names the part: a Macro Scope fits only where `macro` is a macro scope.

Config.AttachmentCategories = {
    scope = { label = 'Scope', icon = 'scope' },
    muzzle = { label = 'Muzzle', icon = 'muzzle' },
    barrel = { label = 'Barrel', icon = 'barrel' },
    grip = { label = 'Grip', icon = 'grip' },
    flashlight = { label = 'Flashlight', icon = 'flashlight' },
    -- Camo is not supported: no category, items or Mk II camo parts.
}

Config.Attachments = {
    -- Scopes
    ['gunny_scope_macro'] = { label = 'Macro Scope', category = 'scope', tier = 'macro', prop = 'w_at_scope_macro' },
    ['gunny_scope_small'] = { label = 'Small Scope', category = 'scope', tier = 'small', prop = 'w_at_scope_small' },
    ['gunny_scope_medium'] = { label = 'Medium Scope', category = 'scope', tier = 'medium', prop = 'w_at_scope_medium' },
    ['gunny_scope_large'] = { label = 'Large Scope', category = 'scope', tier = 'large', prop = 'w_at_scope_large' },
    ['gunny_scope_holographic'] = { label = 'Holographic Sight', category = 'scope', tier = 'holographic', prop = 'w_at_sights_1' },
    ['gunny_scope_thermal'] = { label = 'Thermal Scope', category = 'scope', tier = 'thermal', prop = 'w_at_scope_nv' },   -- GTA uses the night vision model for thermal too
    ['gunny_scope_nightvision'] = { label = 'Night Vision Scope', category = 'scope', tier = 'nightvision', prop = 'w_at_scope_nv' },

    -- Muzzles
    ['gunny_suppressor'] = { label = 'Suppressor', category = 'muzzle', tier = 'suppressor', prop = 'w_at_ar_supp' },
    ['gunny_muzzle_flat'] = { label = 'Flat Muzzle Brake', category = 'muzzle', tier = 'flat', prop = 'w_at_muzzle_1' },
    ['gunny_muzzle_heavy'] = { label = 'Heavy Muzzle Brake', category = 'muzzle', tier = 'heavy', prop = 'w_at_muzzle_5' },
    ['gunny_muzzle_slanted'] = { label = 'Slanted Muzzle Brake', category = 'muzzle', tier = 'slanted', prop = 'w_at_muzzle_6' },
    ['gunny_muzzle_tactical'] = { label = 'Tactical Muzzle Brake', category = 'muzzle', tier = 'tactical', prop = 'w_at_muzzle_2' },
    ['gunny_muzzle_bell'] = { label = 'Bell-End Muzzle Brake', category = 'muzzle', tier = 'bell', prop = 'w_at_muzzle_9' },

    -- Barrels: GTA's Mk II guns have the standard barrel and a heavy one
    ['gunny_barrel_heavy'] = { label = 'Heavy Barrel', category = 'barrel', tier = 'heavy', prop = 'w_at_ar_barrel_2' },

    -- Grips: GTA's one foregrip (COMPONENT_AT_AR_AFGRIP, _02 on the Mk IIs)
    ['gunny_grip_vertical'] = { label = 'Vertical Grip', category = 'grip', tier = 'vertical', prop = 'w_at_ar_afgrip' },

    -- Flashlights
    ['gunny_flashlight'] = { label = 'Flashlight', category = 'flashlight', tier = 'standard', prop = 'w_at_ar_flsh' },
}

Config.WeaponAttachments = {
    -- ========== MK2 PISTOLS ==========
    ['gunny_pistol_mk2'] = {
        scope = {
            macro = `COMPONENT_AT_PI_RAIL`,
            holographic = `COMPONENT_AT_PI_RAIL`,
        },
        muzzle = {
            suppressor = `COMPONENT_AT_PI_SUPP_02`,
            flat = `COMPONENT_AT_PI_COMP`,
        },
        flashlight = { standard = `COMPONENT_AT_PI_FLSH_02` },
    },

    ['gunny_snspistol_mk2'] = {
        scope = { macro = `COMPONENT_AT_PI_RAIL_02` },
        muzzle = {
            suppressor = `COMPONENT_AT_PI_SUPP_02`,
            flat = `COMPONENT_AT_PI_COMP_02`,
        },
        flashlight = { standard = `COMPONENT_AT_PI_FLSH_03` },
    },

    ['gunny_revolver_mk2'] = {
        scope = { holographic = `COMPONENT_AT_SIGHTS` },
        muzzle = { flat = `COMPONENT_AT_PI_COMP_03` },
        flashlight = { standard = `COMPONENT_AT_PI_FLSH` },
    },

    -- ========== MK2 SMGs ==========
    ['gunny_smg_mk2'] = {
        scope = {
            macro = `COMPONENT_AT_SCOPE_MACRO_02_SMG_MK2`,
            small = `COMPONENT_AT_SCOPE_SMALL_SMG_MK2`,
            holographic = `COMPONENT_AT_SIGHTS_SMG`,
        },
        muzzle = {
            suppressor = `COMPONENT_AT_PI_SUPP`,
            flat = `COMPONENT_AT_MUZZLE_01`,
            heavy = `COMPONENT_AT_MUZZLE_02`,
            slanted = `COMPONENT_AT_MUZZLE_03`,
            tactical = `COMPONENT_AT_MUZZLE_04`,
            bell = `COMPONENT_AT_MUZZLE_05`,
        },
        barrel = {
            heavy = `COMPONENT_AT_SB_BARREL_02`,
        },
        flashlight = { standard = `COMPONENT_AT_AR_FLSH` },
    },

    -- ========== MK2 ASSAULT RIFLES ==========
    ['gunny_rifle_mk2'] = {
        scope = {
            macro = `COMPONENT_AT_SCOPE_MACRO_MK2`,
            medium = `COMPONENT_AT_SCOPE_MEDIUM_MK2`,
            holographic = `COMPONENT_AT_SIGHTS`,
        },
        muzzle = {
            suppressor = `COMPONENT_AT_AR_SUPP_02`,
            flat = `COMPONENT_AT_MUZZLE_01`,
            heavy = `COMPONENT_AT_MUZZLE_02`,
            slanted = `COMPONENT_AT_MUZZLE_03`,
            tactical = `COMPONENT_AT_MUZZLE_04`,
            bell = `COMPONENT_AT_MUZZLE_05`,
        },
        barrel = {
            heavy = `COMPONENT_AT_AR_BARREL_02`,
        },
        grip = {
            vertical = `COMPONENT_AT_AR_AFGRIP_02`,
        },
        flashlight = { standard = `COMPONENT_AT_AR_FLSH` },
    },

    ['gunny_carbinerifle_mk2'] = {
        scope = {
            macro = `COMPONENT_AT_SCOPE_MACRO_MK2`,
            medium = `COMPONENT_AT_SCOPE_MEDIUM_MK2`,
            holographic = `COMPONENT_AT_SIGHTS`,
        },
        muzzle = {
            suppressor = `COMPONENT_AT_AR_SUPP`,
            flat = `COMPONENT_AT_MUZZLE_01`,
            heavy = `COMPONENT_AT_MUZZLE_02`,
            slanted = `COMPONENT_AT_MUZZLE_03`,
            tactical = `COMPONENT_AT_MUZZLE_04`,
            bell = `COMPONENT_AT_MUZZLE_05`,
        },
        barrel = {
            heavy = `COMPONENT_AT_CR_BARREL_02`,
        },
        grip = {
            vertical = `COMPONENT_AT_AR_AFGRIP_02`,
        },
        flashlight = { standard = `COMPONENT_AT_AR_FLSH` },
    },

    ['gunny_specialcarbine_mk2'] = {
        scope = {
            macro = `COMPONENT_AT_SCOPE_MACRO_MK2`,
            medium = `COMPONENT_AT_SCOPE_MEDIUM_MK2`,
            holographic = `COMPONENT_AT_SIGHTS`,
        },
        muzzle = {
            suppressor = `COMPONENT_AT_AR_SUPP_02`,
            flat = `COMPONENT_AT_MUZZLE_01`,
            heavy = `COMPONENT_AT_MUZZLE_02`,
            slanted = `COMPONENT_AT_MUZZLE_03`,
            tactical = `COMPONENT_AT_MUZZLE_04`,
            bell = `COMPONENT_AT_MUZZLE_05`,
        },
        barrel = {
            heavy = `COMPONENT_AT_SC_BARREL_02`,
        },
        grip = {
            vertical = `COMPONENT_AT_AR_AFGRIP_02`,
        },
        flashlight = { standard = `COMPONENT_AT_AR_FLSH` },
    },

    ['gunny_bullpuprifle_mk2'] = {
        scope = {
            macro = `COMPONENT_AT_SCOPE_MACRO_02_MK2`,
            small = `COMPONENT_AT_SCOPE_SMALL_MK2`,
            holographic = `COMPONENT_AT_SIGHTS`,
        },
        muzzle = {
            suppressor = `COMPONENT_AT_AR_SUPP`,
            flat = `COMPONENT_AT_MUZZLE_01`,
            heavy = `COMPONENT_AT_MUZZLE_02`,
            slanted = `COMPONENT_AT_MUZZLE_03`,
            tactical = `COMPONENT_AT_MUZZLE_04`,
            bell = `COMPONENT_AT_MUZZLE_05`,
        },
        barrel = {
            heavy = `COMPONENT_AT_BP_BARREL_02`,
        },
        grip = {
            vertical = `COMPONENT_AT_AR_AFGRIP_02`,
        },
        flashlight = { standard = `COMPONENT_AT_AR_FLSH` },
    },

    -- ========== MK2 LMGs ==========
    ['gunny_combatmg_mk2'] = {
        scope = {
            macro = `COMPONENT_AT_SCOPE_MACRO_MK2`,
            medium = `COMPONENT_AT_SCOPE_MEDIUM_MK2`,
            holographic = `COMPONENT_AT_SIGHTS`,
        },
        muzzle = {
            flat = `COMPONENT_AT_MUZZLE_01`,
            heavy = `COMPONENT_AT_MUZZLE_02`,
            slanted = `COMPONENT_AT_MUZZLE_03`,
            tactical = `COMPONENT_AT_MUZZLE_04`,
            bell = `COMPONENT_AT_MUZZLE_05`,
        },
        barrel = {
            heavy = `COMPONENT_AT_MG_BARREL_02`,
        },
        grip = {
            vertical = `COMPONENT_AT_AR_AFGRIP_02`,
        },
    },

    -- ========== MK2 SNIPER RIFLES ==========
    ['gunny_heavysniper_mk2'] = {
        scope = {
            large = `COMPONENT_AT_SCOPE_LARGE_MK2`,
            thermal = `COMPONENT_AT_SCOPE_THERMAL`,
            nightvision = `COMPONENT_AT_SCOPE_NV`,
        },
        muzzle = {
            suppressor = `COMPONENT_AT_SR_SUPP_03`,
            flat = `COMPONENT_AT_MUZZLE_08`,
            heavy = `COMPONENT_AT_MUZZLE_09`,
        },
        barrel = {
            heavy = `COMPONENT_AT_SR_BARREL_02`,
        },
    },

    ['gunny_marksmanrifle_mk2'] = {
        scope = {
            macro = `COMPONENT_AT_SCOPE_MACRO_MK2`,
            medium = `COMPONENT_AT_SCOPE_MEDIUM_MK2`,
            large = `COMPONENT_AT_SCOPE_LARGE_FIXED_ZOOM_MK2`,
            holographic = `COMPONENT_AT_SIGHTS`,
        },
        muzzle = {
            suppressor = `COMPONENT_AT_AR_SUPP`,
            flat = `COMPONENT_AT_MUZZLE_01`,
            heavy = `COMPONENT_AT_MUZZLE_02`,
            slanted = `COMPONENT_AT_MUZZLE_03`,
            tactical = `COMPONENT_AT_MUZZLE_04`,
            bell = `COMPONENT_AT_MUZZLE_05`,
        },
        barrel = {
            heavy = `COMPONENT_AT_MRFL_BARREL_02`,
        },
        grip = {
            vertical = `COMPONENT_AT_AR_AFGRIP_02`,
        },
        flashlight = { standard = `COMPONENT_AT_AR_FLSH` },
    },

    -- ========== MK2 SHOTGUNS ==========
    ['gunny_pumpshotgun_mk2'] = {
        scope = { holographic = `COMPONENT_AT_SIGHTS` },
        muzzle = {
            suppressor = `COMPONENT_AT_SR_SUPP`,
            flat = `COMPONENT_AT_MUZZLE_08`,
        },
        flashlight = { standard = `COMPONENT_AT_AR_FLSH` },
    },

    -- ========== THE OTHERS ==========
    ['gunny_pistol'] = {
        muzzle = { suppressor = `COMPONENT_AT_PI_SUPP_02` },
        flashlight = { standard = `COMPONENT_AT_PI_FLSH` },
    },

    ['gunny_combatpistol'] = {
        muzzle = { suppressor = `COMPONENT_AT_PI_SUPP` },
        flashlight = { standard = `COMPONENT_AT_PI_FLSH` },
    },

    ['gunny_appistol'] = {
        muzzle = { suppressor = `COMPONENT_AT_PI_SUPP` },
        flashlight = { standard = `COMPONENT_AT_PI_FLSH` },
    },

    ['gunny_pistol50'] = {
        muzzle = { suppressor = `COMPONENT_AT_AR_SUPP_02` },
        flashlight = { standard = `COMPONENT_AT_PI_FLSH` },
    },

    ['gunny_snspistol'] = {
        muzzle = { suppressor = `COMPONENT_AT_PI_SUPP_02` },
    },

    ['gunny_heavypistol'] = {
        -- no flashlight: the chrome M1911 (WEAPON_WHIP_HEAVYPISTOL) has no rail
        muzzle = { suppressor = `COMPONENT_AT_PI_SUPP` },
    },

    ['gunny_vintagepistol'] = {
        muzzle = { suppressor = `COMPONENT_AT_PI_SUPP` },
    },

    ['gunny_ceramicpistol'] = {
        muzzle = { suppressor = `COMPONENT_CERAMICPISTOL_SUPP` },
    },

    ['gunny_smg'] = {
        scope = { macro = `COMPONENT_AT_SCOPE_MACRO_02` },
        muzzle = { suppressor = `COMPONENT_AT_PI_SUPP` },
        flashlight = { standard = `COMPONENT_AT_AR_FLSH` },
    },

    ['gunny_microsmg'] = {
        scope = { macro = `COMPONENT_AT_SCOPE_MACRO` },
        muzzle = { suppressor = `COMPONENT_AT_AR_SUPP_02` },
        flashlight = { standard = `COMPONENT_AT_PI_FLSH` },
    },

    ['gunny_assaultsmg'] = {
        scope = { macro = `COMPONENT_AT_SCOPE_MACRO` },
        muzzle = { suppressor = `COMPONENT_AT_AR_SUPP_02` },
        flashlight = { standard = `COMPONENT_AT_AR_FLSH` },
    },

    ['gunny_combatpdw'] = {
        scope = { small = `COMPONENT_AT_SCOPE_SMALL` },
        grip = { vertical = `COMPONENT_AT_AR_AFGRIP` },
        flashlight = { standard = `COMPONENT_AT_AR_FLSH` },
    },

    ['gunny_machinepistol'] = {
        muzzle = { suppressor = `COMPONENT_AT_PI_SUPP` },
    },

    ['gunny_tecpistol'] = {
        muzzle = { suppressor = `COMPONENT_AT_PI_SUPP` },
    },

    ['gunny_rifle'] = {
        scope = { macro = `COMPONENT_AT_SCOPE_MACRO` },
        muzzle = { suppressor = `COMPONENT_AT_AR_SUPP_02` },
        grip = { vertical = `COMPONENT_AT_AR_AFGRIP` },
        flashlight = { standard = `COMPONENT_AT_AR_FLSH` },
    },

    ['gunny_carbinerifle'] = {
        scope = {
            macro = `COMPONENT_AT_SCOPE_MACRO`,
            medium = `COMPONENT_AT_SCOPE_MEDIUM`,
        },
        muzzle = { suppressor = `COMPONENT_AT_AR_SUPP` },
        grip = { vertical = `COMPONENT_AT_AR_AFGRIP` },
        flashlight = { standard = `COMPONENT_AT_AR_FLSH` },
    },

    ['gunny_advancedrifle'] = {
        scope = {
            small = `COMPONENT_AT_SCOPE_SMALL`,
            medium = `COMPONENT_AT_SCOPE_MEDIUM`,
        },
        muzzle = { suppressor = `COMPONENT_AT_AR_SUPP` },
        flashlight = { standard = `COMPONENT_AT_AR_FLSH` },
    },

    ['gunny_specialcarbine'] = {
        scope = {
            macro = `COMPONENT_AT_SCOPE_MACRO`,
            medium = `COMPONENT_AT_SCOPE_MEDIUM`,
        },
        muzzle = { suppressor = `COMPONENT_AT_AR_SUPP_02` },
        grip = { vertical = `COMPONENT_AT_AR_AFGRIP` },
        flashlight = { standard = `COMPONENT_AT_AR_FLSH` },
    },

    ['gunny_bullpuprifle'] = {
        scope = {
            macro = `COMPONENT_AT_SCOPE_MACRO`,
            small = `COMPONENT_AT_SCOPE_SMALL`,
        },
        muzzle = { suppressor = `COMPONENT_AT_AR_SUPP` },
        grip = { vertical = `COMPONENT_AT_AR_AFGRIP` },
        flashlight = { standard = `COMPONENT_AT_AR_FLSH` },
    },

    ['gunny_tacticalrifle'] = {
        muzzle = { suppressor = `COMPONENT_AT_AR_SUPP` },
        flashlight = { standard = `COMPONENT_AT_AR_FLSH` },
    },

    ['gunny_militaryrifle'] = {
        scope = { small = `COMPONENT_AT_SCOPE_SMALL` },
        muzzle = { suppressor = `COMPONENT_AT_AR_SUPP` },
        flashlight = { standard = `COMPONENT_AT_AR_FLSH` },
    },

    ['gunny_heavyrifle'] = {
        scope = {
            macro = `COMPONENT_AT_SCOPE_MACRO`,
            medium = `COMPONENT_AT_SCOPE_MEDIUM`,
        },
        muzzle = { suppressor = `COMPONENT_AT_AR_SUPP` },
        grip = { vertical = `COMPONENT_AT_AR_AFGRIP` },
        flashlight = { standard = `COMPONENT_AT_AR_FLSH` },
    },

    ['gunny_battlerifle'] = {
        scope = { macro = `COMPONENT_AT_SCOPE_MACRO` },
        flashlight = { standard = `COMPONENT_AT_AR_FLSH` },
    },

    ['gunny_mg'] = {
        scope = {
            small = `COMPONENT_AT_SCOPE_SMALL_02`,
            medium = `COMPONENT_AT_SCOPE_MEDIUM`,
        },
    },

    ['gunny_combatmg'] = {
        scope = {
            macro = `COMPONENT_AT_SCOPE_MACRO`,
            medium = `COMPONENT_AT_SCOPE_MEDIUM`,
        },
        grip = { vertical = `COMPONENT_AT_AR_AFGRIP` },
    },

    ['gunny_sniperrifle'] = {
        scope = {
            large = `COMPONENT_AT_SCOPE_LARGE`,
            macro = `COMPONENT_AT_SCOPE_MAX`,
        },
        muzzle = { suppressor = `COMPONENT_AT_AR_SUPP_02` },
    },

    ['gunny_heavysniper'] = {
        scope = { large = `COMPONENT_AT_SCOPE_LARGE` },
    },

    ['gunny_marksmanrifle'] = {
        scope = {
            large = `COMPONENT_AT_SCOPE_LARGE_FIXED_ZOOM`,
        },
        muzzle = { suppressor = `COMPONENT_AT_AR_SUPP` },
        grip = { vertical = `COMPONENT_AT_AR_AFGRIP` },
        flashlight = { standard = `COMPONENT_AT_AR_FLSH` },
    },

    ['gunny_precisionrifle'] = {
        scope = { large = `COMPONENT_AT_SCOPE_LARGE` },
    },

    ['gunny_assaultshotgun'] = {
        muzzle = { suppressor = `COMPONENT_AT_AR_SUPP` },
        grip = { vertical = `COMPONENT_AT_AR_AFGRIP` },
        flashlight = { standard = `COMPONENT_AT_AR_FLSH` },
    },

    ['gunny_heavyshotgun'] = {
        muzzle = { suppressor = `COMPONENT_AT_AR_SUPP_02` },
        grip = { vertical = `COMPONENT_AT_AR_AFGRIP` },
        flashlight = { standard = `COMPONENT_AT_AR_FLSH` },
    },

    ['gunny_pumpshotgun'] = {
        muzzle = { suppressor = `COMPONENT_AT_SR_SUPP` },
        flashlight = { standard = `COMPONENT_AT_AR_FLSH` },
    },

    ['gunny_bullpupshotgun'] = {
        muzzle = { suppressor = `COMPONENT_AT_AR_SUPP_02` },
        grip = { vertical = `COMPONENT_AT_AR_AFGRIP` },
        flashlight = { standard = `COMPONENT_AT_AR_FLSH` },
    },

    ['gunny_combatshotgun'] = {
        flashlight = { standard = `COMPONENT_AT_AR_FLSH` },
        muzzle = { suppressor = `COMPONENT_AT_AR_SUPP` },
    },

    ['gunny_grenadelauncher'] = {
        scope = { small = `COMPONENT_AT_SCOPE_SMALL` },
        flashlight = { standard = `COMPONENT_AT_AR_FLSH` },
    },
}
