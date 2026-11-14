-- whip_gunny — THE WEAPON BENCH (client)
--
-- A bench in the world (config.lua's Config.WeaponBench) with an E prompt. At it with a gun in hand, the bench page
-- opens: the gun floats above the bench with what is fitted, a label pinned to each slot it has (scope, muzzle,
-- grip...), and a camera framing it. The server fits and takes off (server/attachments.lua).
--
-- A slot's label sits on the gun's own bone for it, tried by name (weapons do not agree on bone names), or at a
-- measured offset when the gun has none of them. The labels follow the gun as it turns: sent to the page when one moved.

local BENCH = Config.WeaponBench

--- Bone names per slot, tried in order.
local SLOT_BONES = {
    scope =      { 'WAPScop', 'gun_scope', 'scope' },
    muzzle =     { 'Gun_SuMuzzle', 'gun_muzzle', 'muzzle', 'WAPSupp' },
    barrel =     { 'gun_barrel', 'barrel', 'Gun_SuMuzzle' },
    grip =       { 'WAPGrip', 'gun_grip', 'grip', 'WAPFlshLasr' },
    flashlight = { 'WAPFlshLasr', 'gun_flashlight', 'flashlight' },
}

--- Where a slot's label goes on a gun with none of its bones, from the gun's origin.
local SLOT_OFFSETS = {
    scope =      vector3(0.0, 0.05, 0.05),
    muzzle =     vector3(0.0, 0.35, 0.0),
    barrel =     vector3(0.0, 0.0, 0.06),
    grip =       vector3(0.0, -0.05, -0.05),
    flashlight = vector3(0.0, 0.1, -0.03),
}

local benchEntity = nil
local weaponDisplayEntity = nil
local benchOpen = false
local benchSlots = nil        -- the gun on the bench's slots (its categories): the labels that follow it
local sentPositions = nil     -- the slot positions the page has, so a gun at rest sends nothing
local openBench, closeBench   -- below: the prompt names openBench first

local cachedBoneIndices = {}

--- The bone lookups are per gun: forgotten whenever the gun shown changes.
local function clearBoneCache()
    cachedBoneIndices = {}
end

--- The bench prop, once, and its prompt, every time (Whip.register: whip_core forgets the prompt when it restarts).
local function spawnBench()
    if not BENCH or BENCH.enabled == false then return end

    -- Without its model loaded there is no bench to make; the prompt still goes up, at its place.
    if not (benchEntity and DoesEntityExist(benchEntity)) and GunnyLoadModel(BENCH.model) then
        benchEntity = CreateObject(BENCH.model, BENCH.coords.x, BENCH.coords.y,
            BENCH.coords.z, false, false, false)
        SetModelAsNoLongerNeeded(BENCH.model)   -- the entity holds the model now
        SetEntityRotation(benchEntity, 0.0, 0.0, BENCH.coords.w, 2, true)
        FreezeEntityPosition(benchEntity, true)
        SetEntityAsMissionEntity(benchEntity, true, true)
    end

    local ok, why = exports.whip_core:AddAction({
        id       = 'weapon_bench',
        at       = { coords = vector3(BENCH.coords.x, BENCH.coords.y, BENCH.coords.z) },
        label    = BENCH.label or 'Weapon Bench',
        onSelect = function() openBench() end,
    })
    if not ok then print('[GUNNY] could not add the weapon bench prompt: ' .. tostring(why)) end
end

-- The gun's turn on the bench, kept from one gun shown to the next (a fit shows the same gun again)
local weaponRotation = { x = 0.0, y = 0.0, z = 0.0 }

-- One display gun per weapon, made the first time it is shown and kept, hidden between uses, until gunny stops: on
-- GTA V Enhanced, deleting a CreateWeaponObject gun a few times crashes the game (citizenfx/rfc #495; Cfx's
-- workaround is to keep it and hide it).
local displayGuns = {}   -- [weapon hash] = entity

--- Show the gun above the bench with what is fitted.
local function showGun(weaponName, attachments)
    local previous = weaponDisplayEntity
    local preserveRotation = previous ~= nil and DoesEntityExist(previous)

    clearBoneCache()

    local weaponConfig = Config.GetWeapon(weaponName)
    local weaponHash = weaponConfig and weaponConfig.hash
    if not weaponHash then return false end

    local displayCoords = vector3(BENCH.coords.x, BENCH.coords.y, BENCH.coords.z + 1.1)

    local gun = displayGuns[weaponHash]
    if gun and DoesEntityExist(gun) then
        -- Shown before: every attachment it can take off, and the fitted ones go on below.
        for _, componentHash in ipairs(Config.GetAllAttachmentComponents(weaponName)) do
            if HasWeaponGotWeaponComponent(gun, componentHash) then
                RemoveWeaponComponentFromWeaponObject(gun, componentHash)
            end
        end
    else
        gun = CreateWeaponObject(weaponHash, 1, displayCoords.x, displayCoords.y, displayCoords.z, true, 1.0, 0)
        if not gun or gun == 0 then
            GunnyDebugPrint('Failed to create weapon object for:', weaponName)
            return false
        end
        displayGuns[weaponHash] = gun
        FreezeEntityPosition(gun, true)
        SetEntityCollision(gun, false, false)
    end
    if previous and previous ~= gun and DoesEntityExist(previous) then SetEntityVisible(previous, false, false) end
    weaponDisplayEntity = gun
    SetEntityVisible(gun, true, false)
    SetEntityCoords(weaponDisplayEntity, displayCoords.x, displayCoords.y, displayCoords.z, false, false, false, false)

    if not preserveRotation then
        weaponRotation = { x = 0.0, y = 0.0, z = BENCH.coords.w }
    end
    SetEntityRotation(weaponDisplayEntity, weaponRotation.x, weaponRotation.y, weaponRotation.z, 2, true)

    for category, attachmentItem in pairs(attachments or {}) do
        local attachment = Config.GetAttachment(attachmentItem)
        local componentHash = attachment and Config.GetWeaponAttachmentComponent(weaponName, category, attachment.tier)
        if componentHash then
            -- Its model in, fitted, then let go: the gun holds it now.
            local componentModel = GetWeaponComponentTypeModel(componentHash)
            local loaded = componentModel and componentModel ~= 0 and GunnyLoadModel(componentModel)
            GiveWeaponComponentToWeaponObject(weaponDisplayEntity, componentHash)
            if loaded then SetModelAsNoLongerNeeded(componentModel) end
        end
    end
    return true
end

local function turnGun(deltaX, deltaY)
    if not weaponDisplayEntity or not DoesEntityExist(weaponDisplayEntity) then return end
    weaponRotation.z = weaponRotation.z - deltaX * 0.3
    weaponRotation.x = math.max(-45.0, math.min(45.0, weaponRotation.x + deltaY * 0.3))
    SetEntityRotation(weaponDisplayEntity, weaponRotation.x, weaponRotation.y, weaponRotation.z, 2, true)
end

--- The shown gun's bone for a slot, or -1 when it has none of the slot's bones.
local function slotBone(category)
    if not weaponDisplayEntity or not DoesEntityExist(weaponDisplayEntity) then return -1 end
    if cachedBoneIndices[category] ~= nil then return cachedBoneIndices[category] end

    for _, boneName in ipairs(SLOT_BONES[category] or {}) do
        local boneIndex = GetEntityBoneIndexByName(weaponDisplayEntity, boneName)
        if boneIndex ~= -1 then
            cachedBoneIndices[category] = boneIndex
            return boneIndex
        end
    end
    cachedBoneIndices[category] = -1
    return -1
end

local function slotWorldPos(category)
    if not weaponDisplayEntity or not DoesEntityExist(weaponDisplayEntity) then return nil end

    local boneIndex = slotBone(category)
    if boneIndex ~= -1 then
        local bonePos = GetEntityBonePosition_2(weaponDisplayEntity, boneIndex)
        if #(bonePos - GetEntityCoords(weaponDisplayEntity)) > 0.01 then return bonePos end
    end

    local offset = SLOT_OFFSETS[category]
    if not offset then return nil end
    return GetOffsetFromEntityInWorldCoords(weaponDisplayEntity, offset.x, offset.y, offset.z)
end

local function slotScreenPositions(categories)
    local positions = {}
    if not weaponDisplayEntity or not DoesEntityExist(weaponDisplayEntity) then return positions end
    for _, category in ipairs(categories) do
        local worldPos = slotWorldPos(category)
        if worldPos then
            local onScreen, x, y = GetScreenCoordFromWorldCoord(worldPos.x, worldPos.y, worldPos.z)
            -- Off the screen: no place, and the page hides it.
            positions[category] = onScreen and { x = x, y = y, visible = true } or { visible = false }
        end
    end
    return positions
end

--- Slot positions rounded to the pixel scale the page uses.
local function positionsKey(positions)
    local parts = {}
    for category, p in pairs(positions) do
        parts[#parts + 1] = p.visible and ('%s:%.3f:%.3f'):format(category, p.x, p.y) or (category .. ':off')
    end
    table.sort(parts)
    return table.concat(parts, '|')
end

--- The labels follow the gun as it turns (a drag, the stick, the camera coming in): looked at every frame while the
--- bench is open, sent to the page only when one moved. A job on gunny's one tick (client/main.lua), which runs while
--- a gun is drawn: the bench needs one in hand.
RegisterGunnyTick('bench', function()
    if not (benchOpen and benchSlots) then return end
    local positions = slotScreenPositions(benchSlots)
    local key = positionsKey(positions)
    if key ~= sentPositions then
        sentPositions = key
        SendNUIMessage({ action = 'updateSlotPositions', positions = positions })
    end
end)

--- Hidden, not deleted: kept for the next time (displayGuns).
local function hideGun()
    if weaponDisplayEntity and DoesEntityExist(weaponDisplayEntity) then
        SetEntityVisible(weaponDisplayEntity, false, false)
    end
    weaponDisplayEntity = nil
end

-- ============================================
-- THE CAMERA: whip_core's (PlayCamera), framing the bench
-- ============================================
--
-- Framed by hand for the bench where it first stood (REF_BENCH), and carried to wherever Config.WeaponBench puts it now,
-- turned with it.
local REF_BENCH = vector4(-1069.5194, -1666.3589, 3.3856, 302.7092)
local REF_CAM   = vector3(-1070.3708, -1666.8257, 4.8665)
local REF_ROT   = vector3(-21.6472, 0.0, 301.8667)

local function benchCameraPlacement()
    local b  = Config.WeaponBench.coords
    local dh = (b.w or REF_BENCH.w) - REF_BENCH.w
    local c, s = math.cos(math.rad(dh)), math.sin(math.rad(dh))
    local ox, oy = REF_CAM.x - REF_BENCH.x, REF_CAM.y - REF_BENCH.y
    return vector3(b.x + ox * c - oy * s, b.y + ox * s + oy * c, b.z + (REF_CAM.z - REF_BENCH.z)),
           vector3(REF_ROT.x, REF_ROT.y, REF_ROT.z + dh)
end

local benchCamera = false   -- whip_core's camera is up for the bench

local function startBenchCamera()
    local pos, rot = benchCameraPlacement()
    -- No exit key: the bench page shuts it. Busy (another resource's camera is up): the bench opens without it.
    local ok = Whip.core:PlayCamera({ pos = pos, rot = rot, fov = 50.0, transitionIn = 500, transitionOut = 500,
                                         exitKey = false, async = true })
    benchCamera = ok == true
end

local function stopBenchCamera()
    if not benchCamera then return end
    benchCamera = false
    Whip.core:StopCamera()   -- through Whip.core: our own code (the page's close, a death, a holster)
end

-- ============================================
-- A CONTROLLER
-- ============================================
-- whip's pad reader for screens (Whip.padScreen): the buttons go to the page ('pad', html/script.js padPress), and the
-- right stick turns the gun the way a mouse drag does.
local TURN      = 600    -- the right stick all the way over: this many drag pixels a second (180 deg/s)
local TURN_DEAD = 0.12   -- a resting stick reads a little off centre

local benchPad = Whip.padScreen({
    onFrame = function()
        -- Read disabled: looking is held off while a pad drives.
        local rx, ry = GetDisabledControlNormal(0, 1), GetDisabledControlNormal(0, 2)
        if math.abs(rx) > TURN_DEAD or math.abs(ry) > TURN_DEAD then
            local step = TURN * GetFrameTime()
            turnGun(rx * step, ry * step)
        end
    end,
})

function openBench()   -- the local declared above
    if benchOpen then return end

    if not CurrentWeapon then
        GunnyNotify('You must have a weapon equipped', 'error')
        return
    end

    local attachmentConfig = Config.WeaponAttachments[CurrentWeapon.name]
    if not attachmentConfig or not next(attachmentConfig) then
        GunnyNotify('This weapon does not support attachments', 'error')
        return
    end

    local gun = CurrentWeapon
    local ok, data = GunnyCallback('whip_gunny:getWorkbenchData', GunnySlot(gun.slot, gun.pocket))
    if not ok then
        GunnyNotify(type(data) == 'string' and data or 'Could not open the weapon bench', 'error')
        return
    end
    -- Put away while the server answered (a death, a forced holster): there is no gun to work on, and nothing to open
    -- over the death screen. A second press meanwhile opened it already.
    if CurrentWeapon ~= gun or benchOpen then return end

    benchOpen = true
    -- A screen is open: whip's HUD, minimap, chat and prompts stand aside (IsAnyUIOpen).
    Whip.core:SetUIOpen(true)
    startBenchCamera()

    SendNUIMessage({
        action = 'open',
        label = BENCH.label,
        pad = benchPad:open(),
        weapon = data.weapon,
        attachments = data.attachments,
        -- Shared config the client has already: read here, not sent by the server.
        categories = Config.AttachmentCategories,
        attachmentDefs = Config.Attachments,
        weaponAttachments = Config.WeaponAttachments,
    })
end

function closeBench()   -- the local declared above
    if not benchOpen then return end
    benchOpen = false
    benchSlots = nil

    benchPad:close()      -- no focus, no keep-input, no block
    SendNUIMessage({ action = 'close' })
    hideGun()
    stopBenchCamera()
    Whip.core:SetUIOpen(false)
end

-- Dying or logging out at the bench closes it, and so does the gun leaving the hands (a forced holster, the hands
-- blocked): the bench works on the gun in hand.
AddEventHandler('whip_core:player:died', closeBench)
AddEventHandler('whip_core:player:logout', closeBench)
GunnyAfterHolster(closeBench)

RegisterNUICallback('close', function(_, cb)
    closeBench()
    cb('ok')
end)

RegisterNUICallback('selectWeapon', function(data, cb)
    -- Shut meanwhile (Esc while a fit was answered): no gun shown over a closed bench.
    if not benchOpen or not (data and data.weaponName) then cb({ success = false }) return end
    local success = showGun(data.weaponName, data.attachments)
    benchSlots = data.categories or {}
    -- The page drew its slots again, unplaced: they go to it even if the gun has not moved (a fit shows it at the same turn).
    sentPositions = nil
    cb({ success = success })
end)

RegisterNUICallback('rotateWeapon', function(data, cb)
    if data then turnGun(data.deltaX or 0, data.deltaY or 0) end
    cb({ success = true })
end)

-- The gun is always the one in hand, by its own slot and pocket, never one the page names: the bench works on it. The
-- server answers a fit or a removal with the bench as it is after (the gun, the attachments carried): one round trip.
RegisterNUICallback('installAttachment', function(data, cb)
    if not CurrentWeapon then cb({ success = false, message = 'No weapon in hand' }) return end
    local success, answer = GunnyCallback('whip_gunny:installAttachment',
        GunnySlot(CurrentWeapon.slot, CurrentWeapon.pocket),
        GunnySlot(data.attachmentSlot, data.attachmentPocket))
    if success then
        cb({ success = true, data = type(answer) == 'table' and answer or nil })
    else
        cb({ success = false, message = type(answer) == 'string' and answer or 'Failed to install attachment' })
    end
end)

RegisterNUICallback('removeAttachment', function(data, cb)
    if not CurrentWeapon then cb({ success = false, message = 'No weapon in hand' }) return end
    local success, answer = GunnyCallback('whip_gunny:removeAttachment', GunnySlot(CurrentWeapon.slot, CurrentWeapon.pocket),
        data.category)
    if success then
        cb({ success = true, data = type(answer) == 'table' and answer or nil })
    else
        cb({ success = false, message = type(answer) == 'string' and answer or 'Failed to remove attachment' })
    end
end)

-- ============================================
-- THE DRAWN GUN'S ATTACHMENTS
-- ============================================

RegisterNetEvent('whip_gunny:client:attachmentInstalled', function(weaponSlot, category, attachmentName, componentHash)
    if not CurrentWeapon or CurrentWeapon.slot ~= weaponSlot then return end
    GiveWeaponComponentToPed(PlayerPedId(), CurrentWeapon.hash, componentHash)
    CurrentWeapon.metadata = CurrentWeapon.metadata or {}
    CurrentWeapon.metadata.attachments = CurrentWeapon.metadata.attachments or {}
    CurrentWeapon.metadata.attachments[category] = attachmentName
end)

RegisterNetEvent('whip_gunny:client:attachmentRemoved', function(weaponSlot, category, componentHash)
    if not CurrentWeapon or CurrentWeapon.slot ~= weaponSlot then return end
    if componentHash then
        RemoveWeaponComponentFromPed(PlayerPedId(), CurrentWeapon.hash, componentHash)
    end
    if CurrentWeapon.metadata and CurrentWeapon.metadata.attachments then
        CurrentWeapon.metadata.attachments[category] = nil
    end
end)

--- Fit a gun's attachments on any ped holding it: `attachments` as the gun's metadata has them,
--- { [category] = attachment item }. Drawing a gun calls it (client/weapons.lua).
function ApplyWeaponAttachments(ped, weaponHash, weaponName, attachments)
    for category, attachmentItem in pairs(attachments or {}) do
        local attachment = Config.GetAttachment(attachmentItem)
        local componentHash = attachment and Config.GetWeaponAttachmentComponent(weaponName, category, attachment.tier)
        if componentHash then
            GiveWeaponComponentToPed(ped, weaponHash, componentHash)
        end
    end
end

exports('ApplyWeaponAttachments', ApplyWeaponAttachments)

Whip.register(spawnBench)

-- Stopping: the bench and the display guns go. whip_core puts its camera, the screen and the blocks away itself, and
-- whip's pad screen lets go of the focus.
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if benchEntity and DoesEntityExist(benchEntity) then DeleteEntity(benchEntity) end
    hideGun()
    for hash, gun in pairs(displayGuns) do
        if DoesEntityExist(gun) then DeleteEntity(gun) end
        displayGuns[hash] = nil
    end
end)
