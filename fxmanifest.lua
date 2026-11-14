fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'whip_gunny'
author 'Whippy'
description 'Advanced Weapon System for whip_core'
version '2.0.0'
whip_updates 'WHIPFX/whip_gunny'   -- whip_core checks this repository's releases for a newer version

dependency 'whip_core'

shared_scripts {
    -- whip's satellite helper, first: Whip.register declares to whip_core once it is ready. With the dependency above,
    -- a whip_core restart stops gunny first and starts it again, so nothing here cleans up after whip_core.
    '@whip_core/lib/satellite.lua',

    'config.lua',                -- the settings (and Config itself)
    -- The items gunny adds, then the lookups into them.
    'items/calibers.lua',
    'items/weapons.lua',
    'items/magazines.lua',
    'items/attachments.lua',
    'shared/catalog.lua',
    -- Weapons and magazines from other resources (RegisterWeapon, RegisterMagazine).
    'shared/packs.lua',
    -- Our own guns (WEAPON_WHIP_*) in whip_core's weapon lists: the Director's, the Object Viewer's.
    'shared/whip_weapons.lua',
}

server_scripts {
    'server/main.lua',          -- declaring callbacks and events, the drawn-weapon record
    'server/items.lua',         -- every item registered with whip_core
    'server/weapons.lua',       -- drawing and putting away
    'server/magpanel.lua',      -- a gun's magazine slot
    'server/magazines.lua',     -- loading and unloading magazines
    'server/reload.lua',
    'server/shooting.lua',
    'server/throwables.lua',
    'server/attachments.lua',   -- the weapon bench
    'server/debug.lua',
    'server/ledger.lua',        -- Gunny Debug's ammo ledger: where a loose-round gun's rounds go
}

client_scripts {
    'client/main.lua',          -- asking the server, the drawn weapon, the one per-frame tick
    -- The one owner of the ped's ammunition: before weapons/reload/shooting, which all write through it.
    'client/ammo.lua',
    'client/weapons.lua',
    'client/reload.lua',
    'client/shooting.lua',
    'client/throwables.lua',
    'client/vehicle.lua',       -- shooting from a seat: automatic reloads, RB on a controller
    'client/magazines.lua',     -- loading and unloading, and the magazine in a loading player's hands
    'client/attachments.lua',   -- the weapon bench
    'client/debug.lua',
}

-- The magazine-loading animation (whippy_mag_load.ycd: dict "whippy_mag_load", clip "load_x2", 0.8 s, two rounds)
-- and the round the hand presses in (whippy_mag_round.ydr), whose archetype lets CreateObject make it.
data_file 'DLC_ITYP_REQUEST' 'stream/whippy_mag_round.ytyp'

-- The ammo boxes: one per ammo item (whip_ammobox_<calibre>), printed like its inventory icon. props_src/whip_ammo_props
-- has their sizes, a preview and notes.
data_file 'DLC_ITYP_REQUEST' 'stream/whip_ammo_props.ytyp'

-- The thrown and dropped look of the assault rifle, the Double-Action and the Navy (whip_gunprop_<gun>), props with
-- their own archetype and the gun's collision, so a thrown one lands instead of falling through the ground.
data_file 'DLC_ITYP_REQUEST' 'stream/whip_gun_props.ytyp'

-- gunny's own weapons. Every weapon gunny remodels or retextures is an ADD-ON weapon (WEAPON_WHIP_*) with its own
-- name, models (w_<type>_whip_<name>) and animation entries, so Rockstar's originals stay stock for NPCs, police and
-- every other script; a resource cannot change a base weapon's animation entry. The pump and sawn-off (walnut, their
-- own grips), the AK (wooden stock, bakelite mags), the sniper rifle, the heavy and Mk II revolvers, the Double-Action,
-- the Navy, the knife, dagger, hatchet, machete, bat and golf club. The AK's mags and the Navy's cylinder are add-on
-- components too. Components load before the weapons that list them.
data_file 'CLIP_SETS_FILE' 'data/whip_shotgun_clip_sets.xml'                -- the pump's and sawn-off's whip@ clip sets
data_file 'WEAPONCOMPONENTSINFO_FILE' 'data/whip_weaponcomponents.meta'
data_file 'WEAPON_METADATA_FILE' 'data/whip_weaponarchetypes.meta'          -- the models and texture dictionaries
data_file 'WEAPON_ANIMATIONS_FILE' 'data/whip_weaponanimations.meta'        -- each in its original's animation sets
data_file 'PED_PERSONALITY_FILE' 'data/whip_pedpersonality.meta'            -- movement and holster clips
data_file 'WEAPONINFO_FILE' 'data/whip_weapons.meta'                        -- the weapons: Rockstar's numbers, no pickup

-- The chrome heavy pistol, in files of its own (the same five kinds). No flashlight (no rail) and no Luxe finish (it
-- would swap in Rockstar's gold model).
data_file 'WEAPONCOMPONENTSINFO_FILE' 'data/whip_heavypistol_weaponcomponents.meta'
data_file 'WEAPON_METADATA_FILE' 'data/whip_heavypistol_weaponarchetypes.meta'
data_file 'WEAPON_ANIMATIONS_FILE' 'data/whip_heavypistol_weaponanimations.meta'
data_file 'PED_PERSONALITY_FILE' 'data/whip_heavypistol_pedpersonality.meta'
data_file 'WEAPONINFO_FILE' 'data/whip_heavypistol_weapons.meta'

-- The pump Mk II and the combat shotgun are Rockstar's own: patched in place to reload shell by shell at 0.5 speed. The
-- Mk II takes the combat shotgun's 6-shell clip; its looped clips stream under its own dictionary names.
data_file 'WEAPONINFO_FILE_PATCH' 'data/whip_patch_pumpshotgun_mk2.meta'
data_file 'WEAPONINFO_FILE_PATCH' 'data/whip_patch_combatshotgun.meta'

-- GTA audio, played by the game in the world (client/magazines.lua): the recordings, and what the sound set
-- "whippy_gunny_sounds" plays. Built from audio_src/ by its build.cmd. The data_file names the .rel without ".54.rel".
data_file 'AUDIO_WAVEPACK' 'audiodirectory'
data_file 'AUDIO_SOUNDDATA' 'data/whippy_gunny_sounds.dat'

ui_page 'html/index.html'

-- Only this resource's page may call its NUI callbacks (the bench fits and removes attachments).
nui_callback_strict_mode 'true'

files {
    -- A weapon pack's helper, `shared_script '@whip_gunny/lib/pack.lua'`: listed so a player's game can load it.
    'lib/pack.lua',

    'html/index.html',
    'html/style.css',
    'html/script.js',

    -- Item icons: whip_core looks for an item's icon in the resource that registered it, named after its item key.
    -- WebP is used over PNG when both exist.
    'html/img/items/*.webp',
    'html/img/items/*.png',

    'audiodirectory/whippy_gunny.awc',
    'data/whippy_gunny_sounds.dat54.rel',

    'data/whip_shotgun_clip_sets.xml',
    'data/whip_weaponcomponents.meta',
    'data/whip_weaponarchetypes.meta',
    'data/whip_weaponanimations.meta',
    'data/whip_pedpersonality.meta',
    'data/whip_weapons.meta',
    'data/whip_heavypistol_weaponcomponents.meta',
    'data/whip_heavypistol_weaponarchetypes.meta',
    'data/whip_heavypistol_weaponanimations.meta',
    'data/whip_heavypistol_pedpersonality.meta',
    'data/whip_heavypistol_weapons.meta',
    'data/whip_patch_pumpshotgun_mk2.meta',
    'data/whip_patch_combatshotgun.meta',

    -- No stream/ files here: a streamed .ytyp loads by its name. On Enhanced, which streams stream_enhanced/, a stream/
    -- file listed here is packed into the resource's own files and gunny would not start ("Failed to generate cache for
    -- set: resource.rpf").
}
