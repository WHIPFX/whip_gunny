whip_ammo_props 1.3.1 (2026-10-15) - ammo box props for the whip_gunny ammo items. UNTESTED IN GAME.
================================================================================================================
The inventory icons' boxes (same print) for whip's world items: held in the hand, thrown and lying on the ground.
One prop per ammo item, same names as 1.0.0.

1.3.1 (current): the rocket crate's 12 tiny triangles at its rim corners faced inward (pinholes from outside) -
  flipped; only whip_ammobox_rocket.ydr changed. (The firework pack's 12 odd ones are Rockstar's own: 2 per firework
  rocket model, normals at 90 degrees to the face; left as authored.)
1.3.0:
  - prints fixed: the .50 AE lid top (a bad capture had another face's text over it), the Vom Feuer lids (the F and
    VOM FEUER ran off the edges: 5.56, 7.62, 40mm, the can), the 5.56 / 7.62 backs (a line off the edge, MADE IN GERMANY
    into CARTRIDGES), and every other line or logo that touched an edge (12 gauge lid, firework lid, price stickers, ...);
  - the minigun can: full - four columns of linked rounds over a dark bed (no view to the floor), and the belt's live
    end over the front lip, down the face and out along the floor (as the icon).
  Sizes as 1.2.0:
  - the card boxes are 3x their real size (the 9mm box is 34 cm wide); the 40mm carton 2x (44 cm);
  - four OPEN boxes, 1.4x their real size, lid standing back with the contents showing: the rocket crate (two RPG
    rockets in foam, 1.15 m long), the homing missile case (two missiles in foam, 1.02 m), the minigun can (39 cm) and
    the firework pack (six rockets standing in it, heads out of the top, 96 cm tall with the rockets). These four use
    spec.sps (a second, _s, texture).
  - Same prop names, so the item mapping does not change; replace the stream files.
  (1.1.0: card boxes 4x, the firework pack closed at real size, the other three open at real size.)

  item               prop                        kind                scale  size (W x D x H)       collision
  ammo_9mm           whip_ammobox_9mm            card box            3x    343.8 x 175.8 x  97.5 mm  CARDBOARD_BOX
  ammo_556           whip_ammobox_556            card box            3x    169.8 x 137.4 x 180.6 mm  CARDBOARD_BOX
  ammo_50bmg         whip_ammobox_50bmg          card box            3x    334.8 x 138.6 x 423.6 mm  CARDBOARD_BOX
  ammo_45acp         whip_ammobox_45acp          card box            3x    211.8 x   171 x 101.1 mm  CARDBOARD_BOX
  ammo_50ae          whip_ammobox_50ae           card box            3x    235.8 x 190.2 x 128.4 mm  CARDBOARD_BOX
  ammo_357           whip_ammobox_357            card box            3x    193.8 x 156.6 x 129.6 mm  CARDBOARD_BOX
  ammo_44mag         whip_ammobox_44mag          card box            3x    223.8 x 180.6 x 131.1 mm  CARDBOARD_BOX
  ammo_22lr          whip_ammobox_22lr           card box            3x    244.8 x 126.3 x  84.6 mm  CARDBOARD_BOX
  ammo_762x39        whip_ammobox_762x39         card box            3x    196.8 x   159 x 176.4 mm  CARDBOARD_BOX
  ammo_762x51        whip_ammobox_762x51         card box            3x    207.3 x 167.4 x 221.4 mm  CARDBOARD_BOX
  ammo_308           whip_ammobox_308            card box            3x    406.8 x  87.6 x 221.7 mm  CARDBOARD_BOX
  ammo_12gauge       whip_ammobox_12gauge        card box            3x    358.8 x 358.8 x 197.4 mm  CARDBOARD_BOX
  ammo_36navy        whip_ammobox_36navy         card box            3x    325.8 x 166.8 x  61.5 mm  CARDBOARD_BOX
  ammo_musket        whip_ammobox_musket         card box            3x    307.8 x 127.8 x 248.4 mm  CARDBOARD_BOX
  ammo_flare         whip_ammobox_flare          card box            3x    444.6 x 226.2 x 264.8 mm  CARDBOARD_BOX
  ammo_40mm          whip_ammobox_40mm           card box            2x    437.2 x 293.2 x 248.8 mm  CARDBOARD_BOX
  ammo_emp           whip_ammobox_emp            card box            3x    376.8 x 253.8 x 168.1 mm  CARDBOARD_BOX
  ammo_railgun       whip_ammobox_railgun        card box            3x    262.8 x 109.8 x 240.6 mm  CARDBOARD_BOX
  ammo_energycell    whip_ammobox_energycell     card box            3x    219.3 x 148.8 x 218.4 mm  CARDBOARD_BOX
  ammo_taser         whip_ammobox_taser          card box            3x    331.8 x 115.8 x 122.4 mm  CARDBOARD_BOX
  ammo_firework      whip_ammobox_firework       card pack, open     1.4x    264 x 177.2 x   588 mm  CARDBOARD_BOX
  ammo_rocket        whip_ammobox_rocket         wooden crate, open  1.4x 1151.6 x 347.2 x 162.7 mm  WOOD_SOLID_MEDIUM
  ammo_homingrocket  whip_ammobox_homingrocket   hard case, open     1.4x 1021.2 x 246.4 x 109.2 mm  PLASTIC
  ammo_minigun       whip_ammobox_minigun        ammo can, open      1.4x    392 x   140 x   245 mm  METAL_HOLLOW_MEDIUM

INSTALL
  Either run this folder as its own resource (ensure whip_ammo_props), or copy stream/* into an existing resource's
  stream folder and add its manifest lines:
      files { 'stream/whip_ammo_props.ytyp' }
      data_file 'DLC_ITYP_REQUEST' 'stream/whip_ammo_props.ytyp'
  Then give each ammo item its prop: whip_core takes Config.Items[item].prop (hand prop, thrown prop and ground prop;
  without one it falls back to Config.DefaultGroundProp, prop_cs_cardbox_01). whip_ammo_props.lua has the table.

THE PROPS
  - Origin at the box body's centre; X = the box's width, Y = depth (front face at -Y), Z = up, lid on top (the open
    lids stand up behind the box, hinged on its back edge). Same as Rockstar's shop ammo boxes (v_ret_gc_ammo*) and
    whip's fallback prop_cs_cardbox_01.
  - Collision: one box bound the size of the box body, embedded in the .ydr (Rockstar's margin rule: a quarter of the
    smallest half size, 5 mm to 4 cm); open lids, the firework rockets above the pack and the minigun's hanging belt have none. Card boxes and the
    firework pack use CARDBOARD_BOX (104), as prop_cs_cardbox_01 and the shop boxes; the rocket crate
    WOOD_SOLID_MEDIUM (70), the homing missile case PLASTIC (86), the minigun can METAL_HOLLOW_MEDIUM (59).
  - Archetype flags 537001984 (as prop_cs_cardbox_01), lodDist 100 m (50 m for anything 25 cm or smaller),
    physicsDictionary = the prop's own name (as our working door props).
  - Card boxes: default.sps, one DXT1 texture per prop in its own .ytd (1024x1024 or 2048x1024), 108 triangles.
    Open boxes: spec.sps, a 2048 colour texture (prints, ambient occlusion baked in) + a 1024 spec texture;
    1,788 (case), 2,520 (crate), 4,380 (firework pack) and 21,064 (can: the belt, 8-sided rounds) triangles.
  - whip holds every item prop at one hand offset (SKEL_R_Hand, 0.05 m on X), so the bigger boxes look big in the hand.

FILES
  stream/whip_ammobox_<calibre>.ydr   the model and its collision (24)
  stream/whip_ammobox_<calibre>.ytd   its texture(s) (24)
  stream/whip_ammo_props.ytyp         the 24 archetypes
  whip_ammo_props.lua                 item -> prop table
  props.csv                           sizes, scales, materials, textures
  preview.jpg                         icon | prop front left | back right
  lineup.jpg                          a row of the props at game size beside a 1.8 m figure (and the 1.0.0 9mm box)

Built by E:\GTA V Prop Modifications\work\ammo_props (open_props.py in Blender for the open boxes ->
make_ammo_props.py -> preview.py -> sheet.py -> lineup.py -> finalize.py) from the icons' print (work/ammo_icons/box_tex)
and scenes (ammo_icon.py).
