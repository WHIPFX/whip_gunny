-- whip_gunny — LOADING AND UNLOADING MAGAZINES (client)
--
-- Loading runs on the server (server/magazines.lua): the bar, the animation and the rounds, so a client cannot skip
-- it. This asks, puts the weapon away while the hands are busy, and draws the magazine and rounds in a loading
-- player's hands on every screen nearby.

local loadSeq = 0
local loadAsks = {}      -- [ask] = the promise LoadBullets waits on, answered by whip_gunny:client:loadDone

--- Load as many rounds as fit and the player carries into the magazine at slot, behind the server's bar, 300 ms a
--- round. Waits until the load ends (call from a thread). Answers true and the rounds loaded, or false and why; the
--- player is told either way.
---@param slot number
---@param pocket string|nil  'player' (default) or 'accessory'
---@return boolean ok
---@return number|string loadedOrWhy
function LoadBullets(slot, pocket)
    if not Whip.isReady() then return false, 'whip_core is not running' end
    -- Another bar is already up (a second press while loading).
    if Whip.core:IsProgressActive() == true then return false, 'Busy' end
    loadSeq = loadSeq + 1
    local ask, p = loadSeq, promise.new()
    loadAsks[ask] = p
    -- Answered either way: by the load, or by whip refusing the ask (the event's onReject, server/magazines.lua).
    TriggerServerEvent('whip_gunny:server:loadMagazine', GunnySlot(slot, pocket), ask)
    local answer = Citizen.Await(p)
    return answer[1], answer[2]
end

RegisterNetEvent('whip_gunny:client:loadDone', function(ask, ok, result)
    local p = loadAsks[ask]
    if not p then return end
    loadAsks[ask] = nil
    p:resolve({ ok == true, result })
end)

--- What was in the hand when a load started, given back when it ends.
local heldWeapon = nil

--- The server says a load is starting (true) or over (false, after a refusal too).
RegisterNetEvent('whip_gunny:client:magLoading', function(starting)
    local ped = PlayerPedId()
    if starting then
        local current = GetSelectedPedWeapon(ped)
        if current ~= `WEAPON_UNARMED` then
            heldWeapon = current
            SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        end
    elseif heldWeapon then
        SetCurrentPedWeapon(ped, heldWeapon, true)
        heldWeapon = nil
    end
end)

--- Empty the magazine at slot into the pockets, or `count` rounds of it (nil: all). Answers true and the rounds
--- unloaded, or false and why; the player is told either way. Waits for the server (call from a thread). The
--- inventory's own Unload runs on the server.
---@param slot number
---@param pocket string|nil  'player' (default) or 'accessory'
---@param count number|nil
---@return boolean ok
---@return number|string unloadedOrWhy
function UnloadBullets(slot, pocket, count)
    local ok, result = GunnyCallback('whip_gunny:unloadBulletsFromMag', GunnySlot(slot, pocket), count)
    if not ok then
        local why = type(result) == 'string' and result or 'Could not unload the magazine'
        GunnyNotify(why, 'error')
        return false, why
    end
    GunnyNotify(('Unloaded %d rounds from magazine'):format(result.unloaded), 'success')
    return true, result.unloaded
end

exports('LoadBullets', LoadBullets)
exports('UnloadBullets', UnloadBullets)

-- ============================================
-- THE MAGAZINE IN A LOADING PLAYER'S HANDS
-- ============================================
--
-- The server tells every player nearby when a load starts and ends. Each of their games draws, on its own screen, the
-- magazine in the loader's left hand, a round pinched in the right fingers, and the round on top of the magazine:
-- local objects, because the pinched round blinks in time with the clip, which only a game watching the ped can time.
-- Each round seating clicks through GTA's audio from the loader's ped, so distance, walls and the SFX volume apply
-- (built from audio_src/ into audiodirectory/ and data/). The offsets come from the animation pack (whippy_mag_load).

local DICT, CLIP = 'whippy_mag_load', 'load_x2'
-- ...or, in a vehicle, the same animation without the spine (server/magazines.lua picks). Same length, same hands.
local CLIPS = { CLIP, 'load_x2_seated' }

-- AttachEntityToEntity's rotation order: the pack's rotations are for 2 (YXZ, the game's default). Offsets are
-- bone-local metres and degrees.
local ROT_ORDER = 2

-- The magazine rides SKEL_L_Hand. The pack placed it against PH_L_Hand, a helper bone the clip leaves alone (so the
-- legs move it around under the hand); at rest PH_L_Hand sits PH_L_HAND_X metres along SKEL_L_Hand's x on the
-- skeleton the clip was made on, so the pack's place moves over by that. A fixed number, never measured in game: a
-- measurement catches PH_L_Hand wherever the legs had it.
local PH_L_HAND_X = 0.054434
local MAG   = { model = `w_ar_carbinerifle_mag1`, bone = 18905,           -- SKEL_L_Hand
                pos = vector3(0.03212 + PH_L_HAND_X, 0.08928, -0.00532), rot = vector3(69.417, -143.5524, -31.8939) }
local ROUND = { model = `whippy_mag_round`, bone = 64097,                 -- SKEL_R_Finger12, the index fingertip
                pos = vector3(-0.0105, -0.01345, -0.01247), rot = vector3(42.4971, -47.6785, 43.0481) }
local TOP   = { model = `whippy_mag_round`,                               -- on the magazine itself, not a bone
                pos = vector3(-0.0215, 0.0, 0.0003), rot = vector3(0.0, 0.0, 0.0) }

-- The pinched round shows only in these parts of the clip (0..1): two rounds a loop, each hidden from the moment it
-- seats until the next is in the fingers. Fractions, so they survive a change of clip speed.
local ROUND_SHOWN = { { 0.0, 0.25 }, { 0.41667, 0.75 }, { 0.91667, 1.0 } }

-- The sound: where a round seats (where the pinched round disappears).
local SEATS = { 0.25, 0.75 }
local SEAT_LEAD    = 0.07   -- seconds early: the recording's click is 54 ms in, and the game takes a moment to start it
local HEAR_RANGE   = 25.0   -- metres; past this it is not even started (nearer, the game's falloff and walls decide)
local AUDIO_BANK   = 'audiodirectory/whippy_gunny'   -- fxmanifest: AUDIO_WAVEPACK
local SOUND, SOUND_SET = 'mag_seat', 'whippy_gunny_sounds' -- data/whippy_gunny_sounds.dat54.rel
local CLIP_SECONDS = 0.8    -- the clip's length, if the game will not say

-- How long a start waits for the clip to be playing: the bar loads its animation first (up to two seconds), and
-- another player's clip reaches this screen over the network after that.
local START_WAIT_MS = 4000

local _drawing = {}   -- [loader's server id] = the token of the drawing running for them
local _token   = 0
local _props   = {}   -- [object] = true, every prop alive, so a resource stop can take them all

local function makeProp(model, at)
    local obj = CreateObject(model, at.x, at.y, at.z, false, false, false)
    SetEntityCollision(obj, false, false)
    _props[obj] = true
    return obj
end

local function attach(obj, target, boneIndex, def)
    AttachEntityToEntity(obj, target, boneIndex, def.pos.x, def.pos.y, def.pos.z,
        def.rot.x, def.rot.y, def.rot.z, false, false, false, false, ROT_ORDER, true)
end

local function removeProps(list)
    for _, obj in pairs(list) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
        _props[obj] = nil
    end
end

local function roundShown(phase)
    for _, w in ipairs(ROUND_SHOWN) do
        if phase >= w[1] and phase <= w[2] then return true end
    end
    return false
end

--- Where in the clip (0..1) the sound is sent: each seat, SEAT_LEAD early.
local function cuePhases()
    local len = GetAnimDuration(DICT, CLIP)
    if not len or len <= 0 then len = CLIP_SECONDS end
    local cues = {}
    for i, seat in ipairs(SEATS) do cues[i] = (seat - SEAT_LEAD / len) % 1.0 end
    return cues
end

--- Did the clip pass a cue between last frame's phase and this one's? It loops, so `to` can be below `from`.
local function crossedCue(from, to, cues)
    for _, c in ipairs(cues) do
        if from <= to then
            if c > from and c <= to then return true end
        elseif c > from or c <= to then
            return true
        end
    end
    return false
end

local _bankLoaded = false

--- The audio bank, asked for until the game has it.
local function bankLoaded()
    if not _bankLoaded then _bankLoaded = RequestScriptAudioBank(AUDIO_BANK, false) end
    return _bankLoaded
end

--- One round going in: the click, from the loader's ped (the bank is asked for a second or more before the first).
local function seatSound(ped)
    if #(GetEntityCoords(ped) - GetEntityCoords(PlayerPedId())) > HEAR_RANGE then return end
    if not bankLoaded() then return end
    PlaySoundFromEntity(-1, SOUND, ped, SOUND_SET, false, 0)
end

--- The loader's ped on this screen, or nil when they are not on it.
local function pedOf(loaderId)
    local player = Whip.playerIndex(loaderId)
    if not player then return nil end
    local ped = GetPlayerPed(player)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return ped
end

--- Which of CLIPS the ped is playing, or nil.
local function playingClip(ped)
    for _, clip in ipairs(CLIPS) do
        if IsEntityPlayingAnim(ped, DICT, clip, 3) then return clip end
    end
    return nil
end

--- Draw the magazine on this loader until the load ends, the clip stops, or the ped goes.
---@param loaderId number  the loading player's server id
local function draw(loaderId)
    _token = _token + 1
    local token = _token
    _drawing[loaderId] = token
    local function current() return _drawing[loaderId] == token end

    bankLoaded()

    CreateThread(function()
        -- The clip's dictionary on this screen too (another player's load): its length times the clicks. Not checked:
        -- if it did not load, the clip is never seen playing below, and the wait gives up.
        Whip.core:LoadAnimDict(DICT, 3000)
        -- Not until the clip is playing: a bar that is refused (another already up) never plays it, and drawing at
        -- once would flash a magazine into the hands of someone doing something else.
        local untilT = GetGameTimer() + START_WAIT_MS
        local ped = pedOf(loaderId)
        while current() and not (ped and playingClip(ped)) do
            if GetGameTimer() > untilT then
                if current() then _drawing[loaderId] = nil end
                return
            end
            Wait(50)
            bankLoaded()   -- the game loads a bank while it keeps being asked for
            ped = pedOf(loaderId)
        end
        if not current() then return end

        if not GunnyLoadModel(MAG.model) or not GunnyLoadModel(ROUND.model) then
            if current() then _drawing[loaderId] = nil end
            return
        end
        ped = pedOf(loaderId)
        if not current() or not ped then return end

        local at = GetEntityCoords(ped)
        local props = {
            mag   = makeProp(MAG.model, at),
            round = makeProp(ROUND.model, at),
            top   = makeProp(TOP.model, at),
        }
        SetModelAsNoLongerNeeded(MAG.model)
        SetModelAsNoLongerNeeded(ROUND.model)
        attach(props.mag, ped, GetPedBoneIndex(ped, MAG.bone), MAG)
        attach(props.round, ped, GetPedBoneIndex(ped, ROUND.bone), ROUND)
        attach(props.top, props.mag, 0, TOP)

        -- Every frame: the blink and the click land on the frame the round seats. No click on the first frame: there
        -- is no last frame to have crossed from.
        local cues, last = cuePhases(), nil
        while current() do
            ped = pedOf(loaderId)
            local clip = ped and playingClip(ped)
            if not ped or not clip then break end
            local phase = GetEntityAnimCurrentTime(ped, DICT, clip)
            SetEntityVisible(props.round, roundShown(phase), false)
            if last and crossedCue(last, phase, cues) then seatSound(ped) end
            last = phase
            Wait(0)
        end
        removeProps(props)
        if current() then _drawing[loaderId] = nil end
    end)
end

--- The server: this player's load started (true) or ended (false). Sent to everyone near them.
RegisterNetEvent('whip_gunny:client:magLoadVisual', function(loaderId, on)
    loaderId = tonumber(loaderId)
    if not loaderId then return end
    if on then
        draw(loaderId)
    else
        _drawing[loaderId] = nil   -- the drawing's loop sees it next frame and takes its props away
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    _drawing = {}
    for obj in pairs(_props) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
    _props = {}
    if _bankLoaded then ReleaseNamedScriptAudioBank(AUDIO_BANK) end
end)
