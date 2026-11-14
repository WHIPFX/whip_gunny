-- whip_gunny — LOADING AND UNLOADING MAGAZINES (server)
--
-- A load runs on the server's clock: the server runs the bar (whip_core's Progress refuses an answer sooner than the
-- bar could fill) and the rounds go in only after it, so a modified client cannot skip it. Stopped part way, what went
-- in stays: one round per MS_PER_ROUND of server time since the bar started. A thread, not a callback: a callback
-- cannot wait longer than the client's 10 s, and a drum takes 30.

local MS_PER_ROUND = 300

--- The bar: the magazine-loading loop, walking at most (running cancels), no driving. Flag 49 = upper body + looping +
--- secondary, so the legs stay free. The loop is only a look: MS_PER_ROUND sets the rounds. No `prop`:
--- client/magazines.lua draws the magazine and rounds on every screen nearby, in time with the clip. Seated, the clip
--- without its spine tracks (load_x2 would stand the ped up through the seat). Not in the water (on it or under it) and
--- not falling: the bar does not start there, and stops when one begins (whip_core's notWhile says why).
local MAG_LOAD_BAR = {
    anim     = { dict = 'whippy_mag_load', clip = 'load_x2', flag = 49 },
    seated   = { dict = 'whippy_mag_load', clip = 'load_x2_seated', flag = 49 },
    disable  = { move = 'walk', car = true },
    notWhile = { 'swimming', 'falling' },
}

--- Who is told to draw a loading player's magazine: everyone this close when the load starts.
local MAG_VISUAL_RANGE = 120.0

local loading = {}   -- [source] = true while that player's load is running
local visualTo = {}  -- [source] = { player ids told to draw it }, to tell the same ones it ended

--- Tell the players near `source` to draw — or, with on = false, to take away — the magazine and
--- rounds in their hands. The same players hear the end as heard the start.
---@param source number
---@param on boolean
local function magLoadVisual(source, on)
    if not on then
        for _, target in ipairs(visualTo[source] or {}) do
            TriggerClientEvent('whip_gunny:client:magLoadVisual', target, source, false)
        end
        visualTo[source] = nil
        return
    end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return end
    local at = GetEntityCoords(ped)
    local targets = {}
    for _, id in ipairs(GetPlayers()) do
        local target = tonumber(id)
        local tped = target and GetPlayerPed(target)
        if tped and tped ~= 0 and #(GetEntityCoords(tped) - at) <= MAG_VISUAL_RANGE then
            targets[#targets + 1] = target
            TriggerClientEvent('whip_gunny:client:magLoadVisual', target, source, true)
        end
    end
    visualTo[source] = targets
end

--- What loading this magazine would do right now: how many rounds, or why not.
---@param source number
---@param magAddr table
---@return table|nil plan  { item, meta, currentAmmo, ammoItem, toLoad }
---@return string|nil why
local function planLoad(source, magAddr)
    local slotData = exports.whip_core:GetItemAt(magAddr)
    if not slotData then return nil, 'Magazine not found' end

    local magConfig = Config.GetMagazine(slotData.item)
    if not magConfig then return nil, 'That is not a magazine' end

    local meta = slotData.metadata or {}
    local currentAmmo = meta.ammo or 0
    local spaceLeft = magConfig.capacity - currentAmmo
    if spaceLeft <= 0 then return nil, 'Magazine is full' end

    local caliber = Config.GetCaliber(magConfig.caliber)
    if not caliber then return nil, 'Invalid magazine' end

    local ammoCount = exports.whip_core:GetItemCount(source, caliber.ammoItem) or 0
    if ammoCount < 1 then
        return nil, ('No %s ammunition available'):format(caliber.label or magConfig.caliber)
    end

    -- Both terms are checked positive above, so this can't go negative and destroy rounds.
    return {
        item        = slotData.item,
        meta        = meta,
        currentAmmo = currentAmmo,
        ammoItem    = caliber.ammoItem,
        toLoad      = math.min(spaceLeft, ammoCount),
    }
end

--- Answers true and the rounds loaded, or false and why (the player has been told).
local function runLoad(source, magAddr)
    local plan, why = planLoad(source, magAddr)
    if not plan then
        ---@cast why -nil   -- planLoad says why whenever it has no plan
        exports.whip_core:NotifyPlayer(source, why, 'error')
        return false, why
    end

    TriggerClientEvent('whip_gunny:client:magLoading', source, true)
    magLoadVisual(source, true)
    local startedAt = GetGameTimer()
    local ped = GetPlayerPed(source)
    local seated = ped ~= 0 and GetVehiclePedIsIn(ped, false) ~= 0
    -- Through Whip.call: it waits for the bar, and gunny calls whatever waits that way (server/main.lua's rule).
    local done, barWhy = Whip.call('Progress', source, {
        label     = ('Loading %d rounds into magazine'):format(plan.toLoad),
        duration  = plan.toLoad * MS_PER_ROUND,
        canCancel = true,
        item      = { item = plan.item, metadata = plan.meta },   -- the magazine's picture in the bar's disc
        anim      = seated and MAG_LOAD_BAR.seated or MAG_LOAD_BAR.anim,
        disable   = MAG_LOAD_BAR.disable,
        notWhile  = MAG_LOAD_BAR.notWhile,
    })

    -- How many rounds went in: all of them, or — stopped part way — one per MS_PER_ROUND the bar ran
    -- (see the top of this file). Only a stop the player made counts: cancelling (X, running off,
    -- dying, swimming or falling). Not 'too fast' (the client claimed a finish the clock says it did not
    -- reach), not a 'timeout' (it never answered), not 'player left' or 'whip_core stopped' (nobody to
    -- load for), and not 'refused' (it never started: swimming or falling as it was asked for).
    local count = plan.toLoad
    if not done then
        count = 0
        if barWhy == 'cancelled' or barWhy == 'dead' then
            count = math.min(plan.toLoad, math.floor((GetGameTimer() - startedAt) / MS_PER_ROUND))
        end
        if count < 1 then
            -- 'busy' is another bar that got there first: not a cancel, so not worth a toast. 'refused' was said by
            -- the bar itself ('You cannot do that while swimming').
            if barWhy ~= 'busy' and barWhy ~= 'refused' and barWhy ~= 'player left' and barWhy ~= 'whip_core stopped' then
                exports.whip_core:NotifyPlayer(source, 'Loading cancelled', 'error')
            end
            return false, barWhy == 'busy' and 'Busy' or 'Loading cancelled'
        end
    end

    -- The bar took seconds, so ask again. Never load more than the bar was long enough for.
    local now = planLoad(source, magAddr)
    if not now or now.item ~= plan.item then
        why = 'The magazine or the rounds are not where they were'
        exports.whip_core:NotifyPlayer(source, why, 'error')
        return false, why
    end
    local toLoad = math.min(count, now.toLoad)

    local removed = exports.whip_core:RemoveItem(source, now.ammoItem, toLoad, 'loaded into a magazine')
    if not removed then
        exports.whip_core:NotifyPlayer(source, 'Failed to load bullets', 'error')
        return false, 'Failed to load bullets'
    end

    -- Two halves: the rounds are out of the inventory, so a failed write must put them back.
    now.meta.ammo = now.currentAmmo + toLoad
    if not exports.whip_core:SetItemMetadata(magAddr, now.meta) then
        GunnyWarn('load: the magazine could not be written, so %d rounds go back to the pockets', toLoad)
        GunnyGiveBack(source, now.ammoItem, toLoad, nil, 'loading undone')
        exports.whip_core:NotifyPlayer(source, 'Failed to load bullets', 'error')
        return false, 'Failed to load bullets'
    end

    GunnyDebugPrint('Loaded', toLoad, 'bullets into', now.item, '- now has', now.meta.ammo, 'rounds')
    if done or toLoad >= plan.toLoad then
        exports.whip_core:NotifyPlayer(source, ('Loaded %d rounds'):format(toLoad), 'success')
    else
        exports.whip_core:NotifyPlayer(source, ('Stopped early: loaded %d of %d rounds'):format(toLoad, plan.toLoad), 'success')
    end
    return true, toLoad
end

--- Load as many rounds as fit and the player carries, behind a bar of MS_PER_ROUND each. Waits for
--- the bar, so call it from a thread of its own. One load per player at a time. Answers true and the
--- rounds loaded, or false and why.
---@param source number
---@param magAddr table  the magazine's address (GunnyPocket)
---@return boolean ok
---@return number|string loadedOrWhy
function GunnyLoadMagazine(source, magAddr)
    if loading[source] then return false, 'Busy' end
    loading[source] = true
    local ran, ok, result = pcall(runLoad, source, magAddr)
    loading[source] = nil
    -- Always, even after a refusal: the client gives back the weapon only if it put one away.
    TriggerClientEvent('whip_gunny:client:magLoading', source, false)
    magLoadVisual(source, false)
    if not ran then
        GunnyWarn('magazine load errored: %s', tostring(ok))
        return false, 'Failed to load bullets'
    end
    return ok, result
end

-- The client's LoadBullets export asks through here, and is told how it went (`ask` names its wait), whip's refusal
-- too (onReject). The inventory's Load option calls GunnyLoadMagazine straight from its context action
-- (server/items.lua). The magazine arrives as whip's 'slot' param (GunnyWeaponItems in server/main.lua says what that
-- checks). A burst: a script loads magazine after magazine, and a full one answers at once. One load at a time
-- either way (GunnyLoadMagazine).
RegisterGunnyEvent('whip_gunny:server:loadMagazine', {
    params = {
        { 'mag', 'slot', { item = GunnyMagazineItems } },
        { 'ask', 'id', 1, 2147483647 },
    },
    rateLimit = 200,
    burst     = 5,
    onReject  = function(source, why, raw)
        local ask = math.tointeger(tonumber(type(raw) == 'table' and raw[2] or nil))
        if ask and ask > 0 then TriggerClientEvent('whip_gunny:client:loadDone', source, ask, false, why) end
    end,
}, function(source, _, mag, ask)
    CreateThread(function()
        local ok, result = GunnyLoadMagazine(source, mag.addr)
        TriggerClientEvent('whip_gunny:client:loadDone', source, ask, ok, result)
    end)
end)

AddEventHandler('playerDropped', function()
    loading[source] = nil
    -- Their clients draw nothing once the ped is gone (client/magazines.lua checks every frame); this
    -- only forgets whom to tell.
    visualTo[source] = nil
end)

--- Unload rounds from the magazine at magAddr into the player's pockets — `count` of them, or all
--- of them when count is nil. Answers true, the rounds left and the rounds unloaded; or false and why.
---
--- One body for both ways in: the inventory's Unload option (server/items.lua) and the
--- unloadBulletsFromMag callback below (the client's UnloadBullets export).
---@param source number
---@param magAddr table
---@param count number|nil
---@return boolean ok
---@return number|string remainingOrWhy
---@return number|nil unloaded
function GunnyUnloadMagazine(source, magAddr, count)
    local slotData = exports.whip_core:GetItemAt(magAddr)
    -- Sentences, not codes: the client shows the why as it is.
    if not slotData then return false, 'Magazine not found' end

    local magConfig = Config.GetMagazine(slotData.item)
    if not magConfig then return false, 'That is not a magazine' end

    local meta = slotData.metadata or {}
    local currentAmmo = meta.ammo or 0
    if currentAmmo <= 0 then
        return false, 'That magazine is empty'
    end

    -- How many: at most what it holds. The callback's schema clamps `count` to 1 at least: a negative would invert
    -- the subtraction below and fill the magazine.
    local toUnload = math.min(count or currentAmmo, currentAmmo)

    local caliber = Config.GetCaliber(magConfig.caliber)
    if not caliber then return false, 'This magazine has no ammunition set up' end

    -- Take before give: the rounds come out of the magazine first, then go into the pockets.
    meta.ammo = currentAmmo - toUnload
    if not exports.whip_core:SetItemMetadata(magAddr, meta) then
        return false, 'Could not unload: the magazine was not changed'
    end

    -- Into their pockets or not at all: `noDrop` makes AddItem refuse when the rounds do not fit. Through Whip.call:
    -- the magazine is already lowered, so an answer must come even if whip_core stops meanwhile.
    local added = Whip.call('AddItem', source, caliber.ammoItem, toUnload, nil,
        { reason = 'unloaded from a magazine', noDrop = true })
    if not added then
        -- No room: the rounds go back into the magazine, if it is still the one lowered (AddItem can wait), onto
        -- what it holds now.
        local now = GunnyStillThere(magAddr, slotData.item, meta.serial)
        local nowMeta = now and now.metadata or {}
        nowMeta.ammo = (tonumber(nowMeta.ammo) or 0) + toUnload
        if not (now and Whip.call('SetItemMetadata', magAddr, nowMeta) == true) then
            GunnyWarn('unload: %d rounds of %s LOST (no room for them, and the magazine could not take them back)',
                toUnload, slotData.item)
        end
        return false, 'No room in your pockets for the rounds'
    end

    GunnyDebugPrint('Unloaded', toUnload, 'bullets from', slotData.item, '- now has', meta.ammo, 'rounds')

    return true, meta.ammo, toUnload
end

-- The client's UnloadBullets export asks through here. The lower bound on `count` matters: a negative would add
-- rounds (see GunnyUnloadMagazine). None given is every round (past any magazine's size, and held to what it has).
RegisterGunnyCallback('whip_gunny:unloadBulletsFromMag', { params = {
    { 'mag',   'slot', { item = GunnyMagazineItems } },
    { 'count', 'int',  1, 9999, 9999 },
} }, function(source, _, mag, count)
    local ok, left, unloaded = GunnyUnloadMagazine(source, mag.addr, count)
    if not ok then return false, left end
    return true, { left = left, unloaded = unloaded }
end)
