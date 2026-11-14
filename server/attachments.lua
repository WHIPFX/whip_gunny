-- whip_gunny — THE WEAPON BENCH (server)
--
-- At the bench (BENCH_NEAR) a player fits an attachment they carry to a gun, or takes one off. Take before give, and a
-- half-done change is put back. The page names the gun in their hand by its slot; the server checks it is one of their
-- own guns (whip's 'slot' param), not that it is the one drawn.

--- What the bench page shows: the gun, what is fitted and the slots it has, and every attachment the player carries.
--- Only what the server alone knows: the attachment config is a shared script the client already has. Opening the bench
--- asks for it, and a fit or a removal answers with it, as it is after. Through Whip.core: a removal reads it after
--- AddItem's wait, and whip_core gone meanwhile only empties the list.
---@param source number
---@param weaponItem string
---@param meta table  the gun's metadata
---@return table
local function benchData(source, weaponItem, meta)
    local carried = {}
    for _, attName in ipairs(GunnyAttachmentItems) do
        -- Each found is whip's { item, amount, metadata, addr }; the page names one back by its slot and pocket.
        local all = Whip.core:FindAllItems(source, attName)
        for _, found in ipairs(type(all) == 'table' and all or {}) do
            local attConfig = Config.GetAttachment(found.item)
            if attConfig then
                carried[#carried + 1] = { slot = found.addr.slot, pocket = found.addr.sub, name = found.item,
                                          label = attConfig.label, category = attConfig.category, tier = attConfig.tier }
            end
        end
    end

    return {
        weapon = {
            name = weaponItem,
            attachments = (meta or {}).attachments or {},
            categories = Config.GetWeaponAttachmentCategories(weaponItem),
        },
        attachments = carried,
    }
end

-- Opening the bench: the gun arrives as whip's 'slot' param (this player's own pocket, holding one of gunny's weapons).
RegisterGunnyCallback('whip_gunny:getWorkbenchData', { params = { { 'weapon', 'slot', { item = GunnyWeaponItems } } } },
function(source, _, weapon)
    local attachmentConfig = Config.WeaponAttachments[weapon.item]
    if not Config.GetWeapon(weapon.item) or not attachmentConfig or not next(attachmentConfig) then
        return false, 'This weapon does not support attachments'
    end
    return true, benchData(source, weapon.item, weapon.metadata)
end)

--- Stand at the bench: its position is shared config, so the server checks the player is there. A
--- disabled bench has no position, and whip refuses a move with none (only `allowUnknown` would let it by).
local BENCH_NEAR = {
    range   = 4.0,
    message = 'Stand at the weapon bench',
    at = function()
        local bench = Config.WeaponBench
        if not bench or bench.enabled == false or not bench.coords then return nil end
        return bench.coords.x, bench.coords.y, bench.coords.z
    end,
}

-- Fit one: the weapon and the attachment both arrive as whip's 'slot' param, each in this player's own pockets, not
-- empty, and holding the right kind of item (server/main.lua). Answers true and the bench's data after, or false and
-- why.
RegisterGunnyCallback('whip_gunny:installAttachment', { near = BENCH_NEAR, params = {
    { 'weapon',     'slot', { item = GunnyWeaponItems } },
    { 'attachment', 'slot', { item = GunnyAttachmentItems } },
} },
function(source, _, weapon, attachment)
    local weaponAddr = weapon.addr
    local attachmentName = attachment.item
    local attachmentConfig = Config.GetAttachment(attachmentName)
    if not (Config.GetWeapon(weapon.item) and attachmentConfig) then return false, 'Invalid weapon or attachment' end

    local componentHash = Config.GetWeaponAttachmentComponent(weapon.item, attachmentConfig.category, attachmentConfig.tier)
    if not componentHash then return false, 'This weapon does not take that attachment' end

    local meta = weapon.metadata or {}
    meta.attachments = meta.attachments or {}
    if meta.attachments[attachmentConfig.category] then return false, 'That slot already has an attachment' end

    -- Take before give: the attachment out of the pockets, then onto the gun.
    local removed, takeWhy = exports.whip_core:StoreTake(attachment.addr, 1, { reason = 'fitted to a weapon' })
    if not removed then return false, takeWhy or 'Could not take the attachment' end

    meta.attachments[attachmentConfig.category] = attachmentName
    -- Its whole metadata rides along (kept beside its name, handed back when it comes off): its uid, so its
    -- activity-log timeline continues through the fit. `attachments` stays name-only for the client.
    local fitted = {}
    for k, v in pairs(type(removed) == 'table' and type(removed.metadata) == 'table' and removed.metadata or {}) do
        fitted[k] = v
    end
    meta.attachmentMeta = meta.attachmentMeta or {}
    meta.attachmentMeta[attachmentConfig.category] = fitted
    if not exports.whip_core:SetItemMetadata(weaponAddr, meta) then
        GunnyWarn('fit: the weapon could not be written, so the attachment goes back to the pockets')
        GunnyGiveBack(source, attachmentName, 1, next(fitted) and fitted or nil, 'fitting undone')
        return false, 'Could not save the weapon'
    end

    GunnyDebugPrint('Attachment installed:', attachmentName, 'on', weapon.item, 'slot:', attachmentConfig.category)
    -- The drawn gun shows it at once (client/attachments.lua).
    TriggerClientEvent('whip_gunny:client:attachmentInstalled', source, weaponAddr.slot, attachmentConfig.category, attachmentName, componentHash)
    return true, benchData(source, weapon.item, meta)
end)

-- Take one off. The weapon arrives as whip's 'slot' param (server/main.lua), the slot by its name ('key': refused, never
-- cleaned into another name). Answers true and the bench's data after, or false and why.
RegisterGunnyCallback('whip_gunny:removeAttachment', { near = BENCH_NEAR, params = {
    { 'weapon',   'slot', { item = GunnyWeaponItems } },
    { 'category', 'key',  64 },
} },
function(source, _, weapon, category)
    local weaponAddr = weapon.addr
    local meta = weapon.metadata or {}
    local attachmentName = (meta.attachments or {})[category]
    if not attachmentName then return false, 'No attachment in this slot' end
    local attachmentConfig = Config.GetAttachment(attachmentName)
    if not (Config.GetWeapon(weapon.item) and attachmentConfig) then return false, 'Invalid weapon or attachment' end
    local componentHash = Config.GetWeaponAttachmentComponent(weapon.item, category, attachmentConfig.tier)

    -- Take before give: off the weapon first, then to the player, with the metadata it was fitted with. AddItem can
    -- wait (full pockets drop it on the ground), and a burst of calls during that wait must not see it still fitted.
    -- An older gun may carry only the attachment's uid, in attachmentUids[category]: that comes back as its metadata.
    meta.attachments[category] = nil
    local fitted = type(meta.attachmentMeta) == 'table' and meta.attachmentMeta[category] or nil
    if not fitted and type(meta.attachmentUids) == 'table' and meta.attachmentUids[category] then
        fitted = { uid = meta.attachmentUids[category] }
    end
    if type(meta.attachmentMeta) == 'table' then meta.attachmentMeta[category] = nil end
    if type(meta.attachmentUids) == 'table' then meta.attachmentUids[category] = nil end
    if not exports.whip_core:SetItemMetadata(weaponAddr, meta) then return false, 'Could not save the weapon' end

    -- Through Whip.core: the attachment is off the gun and in nobody's pockets until it lands. It gives or drops, so
    -- it fails only with nowhere at all to go: then back onto the weapon, if it is still there (known by its serial).
    local added = Whip.core:AddItem(source, attachmentName, 1, fitted, 'taken off a weapon')
    if not added then
        local now = GunnyStillThere(weaponAddr, weapon.item, meta.serial)
        local refitted = false
        if now then
            local nowMeta = now.metadata or {}
            nowMeta.attachments = nowMeta.attachments or {}
            nowMeta.attachments[category] = attachmentName
            if fitted then
                nowMeta.attachmentMeta = nowMeta.attachmentMeta or {}
                nowMeta.attachmentMeta[category] = fitted
            end
            refitted = Whip.core:SetItemMetadata(weaponAddr, nowMeta) == true
        end
        if not refitted then GunnyWarn('take off: %s LOST (nowhere to put it, and the weapon could not take it back)', attachmentName) end
        return false, 'No room for the attachment'
    end

    GunnyDebugPrint('Attachment removed:', attachmentName, 'from', weapon.item, 'slot:', category)
    -- The drawn gun drops it at once (client/attachments.lua).
    TriggerClientEvent('whip_gunny:client:attachmentRemoved', source, weaponAddr.slot, category, componentHash)
    return true, benchData(source, weapon.item, meta)
end)
