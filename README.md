# whip_gunny

Weapons for [WHIP](https://github.com/WHIPFX/txAdmin-recipe): guns, magazines, ammunition, attachments, melee weapons,
throwables and the jerry can, all as inventory items. The server counts every round.

## Features

- **Over 100 weapons:** pistols, SMGs, rifles, machine guns, sniper rifles, shotguns, launchers, melee weapons and
  throwables.
- **Guns with state.** Each gun and magazine has a serial number, and each magazine its own round count, saved with
  the inventory.
- **Magazines and calibers.** Ammunition comes in 24 calibers. Players load magazines round by round, and **R** swaps
  in the fullest one they carry. Revolvers and most shotguns load loose rounds, some a shell at a time.
- **The weapon bench.** Scopes, muzzles, barrels, grips and flashlights are items, fitted and removed at the bench.
- **Server-side ammo.** The server records which gun each player has drawn and takes every round fired from its
  count.
- **Shooting from vehicles.** Drive-bys count rounds the same way and reload by themselves.
- **Remodelled weapons.** WHIP's own versions of several guns and blades are add-on weapons, so Rockstar's originals
  stay stock for NPCs, the police and other scripts.
- **Weapon packs.** Add guns from a resource of your own without editing whip_gunny.
- **Controller support.**

## Requirements

- `whip_core`.

## Installation

WHIP's txAdmin recipe installs it.

By hand, put `whip_gunny` in your `resources` folder and add this line to `server.cfg`, after `ensure whip_core`:

```cfg
ensure whip_gunny
```

There's no SQL to import. The items appear in **/whip > Economy > Items**, ready to sell in shops or hand out.

## For players

**Equip** a weapon in the inventory to draw it. **Open** on a gun shows its magazine slot: drag a magazine, or loose
rounds, in or out. **Load Bullets** and **Unload** on a magazine fill and empty it.

| Key | Controller | Does |
| --- | --- | --- |
| **R** | **B** | Reload |
| **G** | **LB + B** | Check ammo, or set off every sticky bomb you've placed |
| **E** at the weapon bench | **A** | Fit or remove attachments on the gun in your hand |

In a vehicle, a gun reloads by itself when it runs dry. On a controller there, double-tap **RB** to start aiming,
then hold it to fire.

Players can rebind **R** and **G** in GTA's **Settings > Key Bindings > FiveM**, and the controller buttons on the
pause menu's **Controller** screen.

## Configuration

`config.lua` sets the weapon bench: whether there is one, and its place, model and name.

The weapons, magazines, calibers and attachments are in `items/`. Each file's header lists its fields. A magazine's
size and a gun's reload time and rounds can also be changed per item in **/whip > Economy > Items**. See **Weapon
System** in WHIP's docs (`whip_core/docs.html`) for adding weapons.

With developer mode on, **/w > Debug > Gunny Debug** shows how the game, whip_gunny and the server each count the
drawn gun's rounds. **A gun that will not reload** in the docs explains each message players see.

## For developers

Add `dependency 'whip_gunny'` to your fxmanifest, then:

- **Server:** `GiveWeapon` and `GiveMagazine` hand out loaded guns and magazines with serials you can track. The
  events `whip_gunny:weapon:drawn`, `:holstered` and `:fired` report every draw, holster and shot.
- **Client:** `GetDrawnWeapon` and `IsWeaponDrawn` read the gun in hand; `DrawWeapon`, `LoadBullets` and
  `UnloadBullets` act on the inventory.
- **Weapon packs:** `RegisterWeapon` and `RegisterMagazine` add your own guns.

Each is documented in WHIP's docs under **Gunny Exports**, **Gunny Client** and **Weapon packs**. **Learning from
gunny** walks through how it's built, as a worked example of a WHIP resource.

## License

whip_gunny is licensed under the GNU LGPL 3.0; see `COPYING.LESSER`, and `COPYING` for the GPL 3.0 it builds on.
`NOTICE.md` says what the licence doesn't cover; `whip_core`'s `NOTICE.md` is the full list.
