@lazyGlobal off.
RunOncePath("calculateStaging").
clearScreen.

set ship:control:pilotMainThrottle to 0.
lock steering to ship:velocity:surface.
local stagesData is GetStagesData().

local targetOrbitalSpeedVector is VectorExclude(body:position, velocity:orbit):normalized * sqrt(body:mu / body:position:mag).
local aimVector is targetOrbitalSpeedVector - velocity:orbit.

local requiredDeltaV is aimVector:mag.
local burnTime is GetBurnTime(requiredDeltaV).

until eta:apoapsis < burnTime / 2
{
    clearScreen.
    print "Coasting to apoapsis: " + Round(eta:apoapsis - (burnTime / 2), 2).
    print "DeltaV to burn: " + Round(aimVector:mag, 2).

    set targetOrbitalSpeedVector to VectorExclude(body:position, velocity:orbit):normalized * sqrt(body:mu / body:position:mag).
    set aimVector to targetOrbitalSpeedVector - velocity:orbit.
    
    set requiredDeltaV to aimVector:mag.
    set burnTime to GetBurnTime(requiredDeltaV).

    wait 1.
}

lock steering to aimVector.
wait until VectorAngle(aimVector, ship:facing:forevector) < 1.

set ship:control:pilotMainThrottle to 1.
wait until ship:thrust > 0.

local acceleration is ship:thrust / ship:mass.
until targetOrbitalSpeedVector:mag < velocity:orbit:mag
{
    clearScreen.
    print "DeltaV to burn: " + Round(aimVector:mag, 2).

    if ship:thrust = 0
    {
        stage.
        wait until ship:thrust > 0.
    }

    set acceleration to ship:thrust / ship:mass. 
    set targetOrbitalSpeedVector to VectorExclude(body:position, velocity:orbit):normalized * sqrt(body:mu / body:position:mag).
    set aimVector to targetOrbitalSpeedVector - velocity:orbit.

    if aimVector:mag / acceleration <= 1
    {
        set ship:control:pilotMainThrottle to max(0.01, ship:control:pilotMainThrottle / 2).
    }

    wait 0.
}

set ship:control:pilotMainThrottle to 0.
unlock steering.

local function GetBurnTime
{
    local parameter requiredDeltaV.

    local burnTime is 0.
    local exhaustVelocity is 1.

    local currentStage is ship:stageNum.
    local stageDeltaV is 1.
    until requiredDeltaV <= 0 or currentStage < 0
    {
        set exhaustVelocity to stagesData[currentStage]["totalVacuumThrust"] / stagesData[currentStage]["massFlow"].
        set stageDeltaV to exhaustVelocity * ln(stagesData[currentStage]["totalMass"] / stagesData[currentStage]["endMass"]).
        set burnTime to burnTime + -stagesData[currentStage]["totalMass"] * (1 - constant:e ^ (min(stageDeltaV, requiredDeltaV) / exhaustVelocity)) / stagesData[currentStage]["massFlow"].

        set requiredDeltaV to requiredDeltaV - stageDeltaV.
        set currentStage to currentStage - 1.
    }

    return burnTime.
}