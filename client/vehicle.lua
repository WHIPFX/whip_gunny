-- whip_gunny — SHOOTING FROM A SEAT (client)
--
-- GTA's drive-by does the shooting; the shots are counted as on foot (client/shooting.lua). In a vehicle:
--   * Reloading is automatic, and the only way: the last round fired from a seat reloads, and so does
--     pulling the trigger on an empty gun. R and B do nothing here (client/reload.lua). It is R's
--     reload all the same, which takes at least the weapon's reloadTime in a seat, whether or not the
--     game plays an animation there.
--   * On a controller, a double tap on RB turns aiming on and it stays on (the aim LB would give is put
--     in for the player); another double tap turns it off. Not aiming, RB is the handbrake as usual and
--     never fires. Aiming, RB fires only once it has been held HOLD_MS; a tap fires nothing, so neither
--     a stray tap nor the double tap that turns aiming off ever shoots. LB never aims, because LB + A
--     is talk.

-- Driver / passenger: aim, fire.
local DRIVER    = { aim = 68, fire = 69 }
local PASSENGER = { aim = 91, fire = 92 }
local HANDBRAKE = 76

-- RB held HOLD_MS fires; a shorter press is a tap. A double tap is a second press within GAP_MS of a tap.
local HOLD_MS, GAP_MS = 100, 220

-- A pad is in the player's hands: asked once whip_core is up, then whip_core says when it changes (settled over
-- 400 ms), so the tick never asks.
local onPad = false
Whip.register(function() onPad = Whip.core:IsControllerActive() == true end)
AddEventHandler('whip_core:pad:deviceChanged', function(d) onPad = type(d) == 'table' and d.pad == true end)

-- Aiming on; RB's press while it is down ({ at, toggle, firing }); when the last tap ended.
local aiming = false
local press, tapEndedAt = nil, nil

local function resetPad()
    aiming, press, tapEndedAt = false, nil, nil
end

-- The pad block, change-tracked:
--   'idle'  not aiming: LB's aim and RB's fire held off (the handbrake is RB's)
--   'aim'   aiming, RB not firing: the handbrake and RB's fire held off until a press is held HOLD_MS
--   'fire'  aiming and firing: the handbrake only (the aim put in and RB's own fire must stay enabled,
--           or the game ignores them)
local PAD_BLOCK = 'padDriveBy'
local BLOCKS = {
    idle = { DRIVER.aim, PASSENGER.aim, DRIVER.fire, PASSENGER.fire },
    aim  = { DRIVER.fire, PASSENGER.fire, HANDBRAKE },
    fire = { HANDBRAKE },
}
local padBlock = nil
local blockRefusalSaid = false

--- Held as asked only once whip_core says yes; refused, it is asked again on the next frame, and the reason said once.
local function setPadBlock(state)
    if state == padBlock then return end
    local ok, why
    if state then ok, why = Whip.core:BlockControls(PAD_BLOCK, { controls = BLOCKS[state] })
    else ok, why = Whip.core:UnblockControls(PAD_BLOCK) end
    if ok == true or not state then
        padBlock = state
    elseif not blockRefusalSaid then
        blockRefusalSaid = true
        print('[GUNNY] the seat controls could not be held: ' .. tostring(why))
    end
end

--- Reload from a seat: R's reload (client/reload.lua), which stops firing at once and runs in its own thread, as it
--- waits on the server and the animation, and the tick that calls this counts the shots too.
function GunnyReloadInVehicle()
    GunnyStartReload()
end

local function emptyGun()
    return (CurrentWeapon.ammo or 0) == 0 and not GunnyReloading
end

--- RB this frame, read through the block.
local function readRB(fire, now)
    if IsDisabledControlJustPressed(0, fire) then
        if tapEndedAt and now - tapEndedAt <= GAP_MS then
            aiming = not aiming
            tapEndedAt = nil
            press = { at = now, toggle = true }   -- the second tap: it never fires, however long it is held
        else
            press = { at = now }
        end
    elseif press and not IsDisabledControlPressed(0, fire) then
        if not press.toggle and not press.firing and now - press.at < HOLD_MS then
            tapEndedAt = now
        else
            tapEndedAt = nil
        end
        press = nil
    end
end

--- Aiming: RB fires once it has been held HOLD_MS (a tap fires nothing). An empty gun reloads instead.
local function aimFrame(now)
    if press and not press.toggle and not press.firing and now - press.at >= HOLD_MS then
        press.firing = true
        if emptyGun() then GunnyReloadInVehicle() end
    end
    return press ~= nil and press.firing == true
end

RegisterGunnyTick('vehicle', function(ped, now)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or not Config.IsFirearm(CurrentWeapon.config) then
        setPadBlock(nil)
        resetPad()
        return
    end

    local seat = GetPedInVehicleSeat(veh, -1) == ped and DRIVER or PASSENGER

    if not onPad then
        setPadBlock(nil)
        resetPad()
        -- Trigger pulled on an empty gun: reload. IsControlJustPressed is false while a block holds it.
        if emptyGun() and IsControlJustPressed(0, seat.fire) then GunnyReloadInVehicle() end
        return
    end

    readRB(seat.fire, now)
    if aiming then
        local firing = aimFrame(now)
        setPadBlock(firing and 'fire' or 'aim')
        SetControlNormal(0, seat.aim, 1.0)
    else
        setPadBlock('idle')
    end
end)

GunnyAfterHolster(function()
    setPadBlock(nil)
    resetPad()
end)
