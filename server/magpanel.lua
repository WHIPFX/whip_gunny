-- whip_gunny — the magazine slot, DECLARED
--
-- The weapon's magazine slot is a declared panel (RegisterPanelItem): whip_core performs the move,
-- resolves the host weapon from the inventory, and folds each change into it as it happens. This
-- file only says what the slot shows and what may go in.
--
-- Two shapes, one declaration: a magazine weapon stores `meta.magazine`, the magazine's whole metadata
-- with its item name (GunnyMagazineIn, server/main.lua), a magless one stores `meta.ammo`, a number. The
-- panel is a view of that metadata: read renders either shape as a slot, write folds the slot back into
-- the same shape.

--- Is this weapon magless (loose rounds in a chamber) rather than magazine-fed?
local function isMagless(weaponItem)
    local cfg = Config.GetWeapon(weaponItem)
    return cfg and cfg.magless or false
end

--- Build the panel view of a weapon's loaded ammunition.
local function readWeaponPanel(host)
    local meta = host.metadata or {}

    if isMagless(host.item) then
        local ammo = meta.ammo or 0
        if ammo <= 0 then return {} end
        local ammoItem = Config.GetAmmoItemForWeapon(host.item)
        if not ammoItem then return {} end
        -- A count, rendered as a stack.
        return { [1] = { item = ammoItem, amount = ammo } }
    end

    local mag = meta.magazine
    if not mag then return {} end
    local item, metadata = GunnyMagazineOut(mag)
    return { [1] = { item = item, amount = 1, metadata = metadata } }
end

--- May this move happen? Runs before anything is touched, with the WEAPON in scope.
---
--- Whether a magazine fits depends on the weapon and what's already in it, which a flat
--- `allowedItems` list can't express.
---
--- One table, `ctx`, like every panel hook in whip; the weapon is `ctx.host`.
local function validateWeaponPanel(ctx)
    local host = ctx.host
    -- Either way, not while the gun is being loaded a shell at a time: the client is counting the shells going in.
    if GunnyLoopedReloadOpen(host.source, host.slot, host.addr.sub) then return false, 'Finish reloading first' end
    -- Taking something out is always allowed; the checks below are all about what goes in.
    if ctx.direction ~= 'in' then return true end

    local weaponCfg = Config.GetWeapon(host.item)
    if not weaponCfg then return false, 'Unknown weapon' end

    local meta = host.metadata or {}

    if weaponCfg.magless then
        local expected = Config.GetAmmoItemForWeapon(host.item)
        if ctx.item ~= expected then
            local caliber = Config.GetCaliber(weaponCfg.caliber)
            return false, ('Only accepts %s ammunition')
                :format(caliber and caliber.label or tostring(weaponCfg.caliber))
        end

        local capacity = weaponCfg.internalCapacity
        -- On a SWAP the rounds already in the chamber are leaving as these arrive (whip_core asks
        -- about the returning half of a swap with ctx.swap set), so they do not count against it.
        local current  = ctx.swap and 0 or (meta.ammo or 0)
        if current + (ctx.amount or 1) > capacity then
            return false, ('Chamber full — it holds %d rounds'):format(capacity)
        end
        return true
    end

    if not Config.GetMagazine(ctx.item) then
        return false, 'Only magazines can be inserted'
    end
    if not Config.IsMagCompatible(host.item, ctx.item) then
        return false, 'That magazine does not fit this weapon'
    end
    -- A swap is allowed either way: the new magazine dropped onto the fitted one (ctx.replacing) or
    -- the fitted one dragged onto the new one (ctx.swap). Only a second magazine beside it is refused.
    if meta.magazine and not ctx.swap and not ctx.replacing then
        return false, 'Remove the current magazine first'
    end
    return true
end

--- Fold the panel back into the weapon's own metadata shape.
local function writeWeaponPanel(host, items)
    local meta = host.metadata or {}
    local held = items and items[1] or nil

    if isMagless(host.item) then
        -- Back to a plain count of this gun's own ammunition only: anything else in the slot (should
        -- it ever get past validateWeaponPanel) is never counted as rounds.
        local ammoItem = Config.GetAmmoItemForWeapon(host.item)
        meta.ammo = (held and held.item == ammoItem) and held.amount or 0
        return meta
    end

    if not held then
        meta.magazine = nil
        return meta
    end

    meta.magazine = GunnyMagazineIn(held.item, held.metadata)
    return meta
end

--- Post-commit. Only reached once the move has actually landed, which is what makes it the
--- right place to touch the ped: swapping the visual magazine component for a move that then
--- failed would leave the model disagreeing with the inventory. `ctx.host` is the weapon, read
--- after the change was folded into it.
local function onWeaponPanelChange(ctx)
    local host = ctx.host
    local meta = host.metadata or {}
    -- The rounds changed here, not by a shot: a count the client sent for what was in it before is ignored. Nil when
    -- this is not the drawn gun (same pocket, slot and serial: the accessory strip reuses slot numbers), and then there
    -- is nothing in the hand to change.
    local countVersion = GunnyCountChanged(host.source, host.addr, meta.serial)
    if not countVersion then return end

    if isMagless(host.item) then
        GunnyLedgerGun(host.source, host.item, meta.serial, 'chamber panel', nil, meta.ammo or 0)   -- server/ledger.lua
        -- The client has separate handlers for gaining and losing chamber rounds, so the
        -- direction of the move picks which one. 'in' and 'out' are from the PANEL's point of
        -- view: into the panel means into the gun.
        local ev = ctx.direction == 'out'
            and 'whip_gunny:client:maglessAmmoRemoved'
            or 'whip_gunny:client:maglessAmmoInserted'
        TriggerClientEvent(ev, host.source, host.slot, meta.ammo or 0, countVersion)
        return
    end

    if meta.magazine then
        TriggerClientEvent('whip_gunny:client:magazineInserted', host.source, host.slot,
            meta.magazine.ammo or 0, countVersion, meta.magazine.item)
    else
        TriggerClientEvent('whip_gunny:client:magazineRemoved', host.source, host.slot, countVersion)
    end
end

--- Declare one gun's magazine slot, after its item is registered: a panel naming an item whip_core has never heard of
--- is refused. Every gun shares the one 'whip_gunny:open_weapon' action (whip_core dispatches on the item used).
--- Answers whether it was declared; a melee weapon, the jerry can or a throwable has none.
---@param weaponItem string
---@return boolean
function RegisterGunnyMagPanel(weaponItem)
    local weaponCfg = Config.Weapons[weaponItem]
    -- Guns only: a melee weapon has no rounds, the jerry can's fuel is its metadata, a throwable's stack its count.
    if not Config.IsFirearm(weaponCfg) then return false end
    local ok, err = exports.whip_core:RegisterPanelItem(weaponItem, {
        action = 'whip_gunny:open_weapon',
        slots  = 1,
        label  = (weaponCfg.label or 'Weapon') .. (weaponCfg.magless and ' Chamber' or ' Mag'),

        read       = readWeaponPanel,
        onValidate = validateWeaponPanel,
        write      = writeWeaponPanel,
        onChange   = onWeaponPanelChange,
    })
    if not ok then Whip.startProblem('could not register the magazine panel for "%s": %s', weaponItem, tostring(err)) end
    return ok == true
end
