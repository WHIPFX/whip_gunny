# whip_gunny

Guns, magazines, ammunition, melee weapons, throwables and the jerry can for **whip_core**. It is also the worked
example of a resource built the way whip expects.

## Install

WHIP's txAdmin recipe installs it and adds `ensure whip_gunny` to server.cfg (whip_core starts first: its manifest asks for it).
Nothing else to set up, no SQL. The items appear in /whip → Economy → Items, ready to sell in shops or hand out.

## Docs

gunny's docs are part of whip's: the **whip_gunny** group of whip's docs page (`whip_core/docs.html`).

- **Weapon System**: how it works, magazines and calibers, the weapon bench, controls, the jerry can and throwables,
  adding weapons, weapon packs, giving weapons from your own resource, debugging.
- **Learning from gunny**: the patterns worth copying, each with gunny's own code, and where each part of gunny
  lives.
- **Gunny Exports** and **Gunny Client**: every export and event.

## Credits

- Barlow, the bench page's typeface, comes with whip_core (SIL Open Font License).
