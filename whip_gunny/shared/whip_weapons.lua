-- whip_gunny — GUNNY'S OWN GUNS IN WHIP'S WEAPON LISTS (Whip.weapons)
--
-- The 15 add-on weapons gunny streams (WEAPON_WHIP_*: data/whip_weapons.meta, data/whip_heavypistol_weapons.meta),
-- offered beside GTA's wherever whip_core lists weapons: the Director's NPC weapons and its Hold a Weapon step, its
-- Fixed Weapons (the firearms, by their world models), Dungeon Mode, the Object Viewer's Give a weapon. Each shows as
-- "Pump Shotgun (gunny)". GTA's own pump stays in the lists too: it is the one police and other scripts use.
--
-- An NPC given one carries the gun itself, not our item: no magazines, ammo types or reloads of ours on it.
-- Labels are the items' own (items/weapons.lua). Both sides: whip_core keeps the list on the server and on each game.

local OWN = {
    -- Firearms: each <Model> from the metas, so they can be Fixed Weapons too.
    { name = 'WEAPON_WHIP_HEAVYPISTOL',    group = 'pistol',  model = 'w_pi_whip_heavypistol' },
    { name = 'WEAPON_WHIP_REVOLVER',       group = 'pistol',  model = 'w_pi_whip_revolver' },
    { name = 'WEAPON_WHIP_REVOLVER_MK2',   group = 'pistol',  model = 'w_pi_whip_revolvermk2' },
    { name = 'WEAPON_WHIP_DOUBLEACTION',   group = 'pistol',  model = 'w_pi_whip_wep1_gun' },
    { name = 'WEAPON_WHIP_NAVYREVOLVER',   group = 'pistol',  model = 'w_pi_whip_wep2_gun' },
    { name = 'WEAPON_WHIP_ASSAULTRIFLE',   group = 'rifle',   model = 'w_ar_whip_assaultrifle' },
    { name = 'WEAPON_WHIP_PUMPSHOTGUN',    group = 'shotgun', model = 'w_sg_whip_pumpshotgun' },
    { name = 'WEAPON_WHIP_SAWNOFFSHOTGUN', group = 'shotgun', model = 'w_sg_whip_sawnoff' },
    { name = 'WEAPON_WHIP_SNIPERRIFLE',    group = 'sniper',  model = 'w_sr_whip_sniperrifle' },
    -- Melee: for NPCs to carry.
    { name = 'WEAPON_WHIP_BAT',            group = 'melee' },
    { name = 'WEAPON_WHIP_DAGGER',         group = 'melee' },
    { name = 'WEAPON_WHIP_GOLFCLUB',       group = 'melee' },
    { name = 'WEAPON_WHIP_HATCHET',        group = 'melee' },
    { name = 'WEAPON_WHIP_KNIFE',          group = 'melee' },
    { name = 'WEAPON_WHIP_MACHETE',        group = 'melee' },
}

--- The item's label for a weapon (Config.Weapons, by its hash), or nil.
local function labelOf(name)
    local want = GetHashKey(name) & 0xFFFFFFFF
    for _, w in pairs(Config.Weapons) do
        local h = math.tointeger(w.hash)
        if h and (h & 0xFFFFFFFF) == want then return w.label end
    end
    return nil
end

local list = {}
for _, w in ipairs(OWN) do
    list[#list + 1] = { name = w.name, label = labelOf(w.name) or w.name, group = w.group, model = w.model }
end
Whip.weapons(list, { tag = 'gunny' })
