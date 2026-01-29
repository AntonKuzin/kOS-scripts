@lazyGlobal off.
RunOncePath("calculateStaging").
RunOncePath("motionPrediction").
RunOncePath("burnSimulation").
clearScreen.

set ship:control:pilotMainThrottle to 0.
lock steering to ship:velocity:surface.

local burnStartOffset is eta:apoapsis.
local burnStartTime is TimeStamp() + burnStartOffset.
local initialVelocityVector is GetVectorAdjustedForRotation(VelocityAt(ship, burnStartTime):orbit, burnStartOffset).
local targetOrbitalSpeedVector is initialVelocityVector:normalized * sqrt(body:mu / (PositionAt(ship, burnStartTime) - body:position):mag).
local aimVector is targetOrbitalSpeedVector - initialVelocityVector.
local aimCandidateVector is aimVector.
local aimCorrectionVector is V(0, 0, 0).

local currentAcceleration is 1.
local currentStage is ship:stageNum.
local stagesData is GetStagesData().
local shipState is CreateShipState().
local stateChangeSources is CreateStateChangeSources().
local integrator is CreateBurnIntegrator(shipState, stateChangeSources, stagesData, 8,
    { return shipState["velocityVector"]:mag >= targetOrbitalSpeedVector:mag and shipState["mass"] >= stagesData[0]["endMass"]. },
    {
        set aimCorrectionVector to targetOrbitalSpeedVector - shipState["velocityVector"].
        set currentAcceleration to stagesData[integrator["currentStage"]]["totalVacuumThrust"] / shipState["mass"].
        return aimCorrectionVector:mag / currentAcceleration / 2.
    }).
set stateChangeSources["thrustDelegate"] to { local parameter state. return -aimCandidateVector:normalized * stagesData[integrator["currentStage"]]["totalVacuumThrust"]. }.

local requiredDeltaV is aimVector:mag.
local requiredDeltaVCandidate is requiredDeltaV.
local halfBurnTime is GetBurnTime(requiredDeltaV / 2).
set burnStartOffset to eta:apoapsis - halfBurnTime.

local insertionAltitude is orbit:apoapsis.
until TimeStamp():seconds > burnStartTime
{
    UpdateShipState(shipState).
    set shipState["radiusVector"] to GetVectorAdjustedForRotation(PositionAt(ship, burnStartTime) - body:position, burnStartOffset).
    set shipState["velocityVector"] to GetVectorAdjustedForRotation(VelocityAt(ship, burnStartTime):orbit, burnStartOffset).
    set shipState["surfaceVelocityVector"] to GetVectorAdjustedForRotation(VelocityAt(ship, burnStartTime):surface, burnStartOffset).

    set initialVelocityVector to shipState["velocityVector"].
    RunPredictorCorrectorIteration().

    set halfBurnTime to GetBurnTime(requiredDeltaV / 2).
    set burnStartOffset to eta:apoapsis - halfBurnTime.
    set burnStartTime to TimeStamp() + burnStartOffset.

    clearScreen.
    print "Coasting to apoapsis: " + Round(burnStartOffset , 2).
    print "DeltaV to burn: " + Round(requiredDeltaV, 2).
    print "Orbital insertion altitude: " + Round(insertionAltitude, 0).

    wait 0.
}

lock steering to aimVector.
set ship:control:pilotMainThrottle to 1.
wait until ship:thrust > 0.

local acceleration is ship:thrust / ship:mass.
until (targetOrbitalSpeedVector - velocity:orbit):mag < 10
{
    until ship:mass > stagesData[ship:stageNum]["endMass"]
        or stagesData[ship:stageNum]["massFlow"] > 0
        or ship:stageNum = 0
    {
        stage.
        wait until stage:ready.
    }

    UpdateShipState(shipState).

    set initialVelocityVector to shipState["velocityVector"].
    RunPredictorCorrectorIteration().

    set acceleration to ship:thrust / ship:mass. 
    if (targetOrbitalSpeedVector - ship:velocity:orbit):mag <= acceleration
    {
        set ship:control:pilotMainThrottle to max(0.01, ship:control:pilotMainThrottle / 2).
    }

    clearScreen.
    print "Orbital insertion".
    print "DeltaV to burn: " + Round(integrator["deltaVRequired"], 2).
    print "Insertion altitude: " + Round(insertionAltitude, 0).

    wait 0.
}

set targetOrbitalSpeedVector to VectorExclude(body:position, velocity:orbit):normalized * sqrt(body:mu / body:position:mag).
set aimVector to targetOrbitalSpeedVector - velocity:orbit.
until aimVector:mag < 0.01
{
    clearScreen.
    print "Terminal phase.".
    print "DeltaV to burn: " + Round(aimVector:mag, 2).
    
    set acceleration to ship:thrust / ship:mass.
    set ship:control:pilotMainThrottle to min(0.1, aimVector:mag / acceleration / 10).

    set targetOrbitalSpeedVector to VectorExclude(body:position, velocity:orbit):normalized * sqrt(body:mu / body:position:mag).
    set aimVector to targetOrbitalSpeedVector - velocity:orbit.

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
        set stageDeltaV to 0.
        if stagesData[currentStage]["massFlow"] > 0
        {
            set exhaustVelocity to stagesData[currentStage]["totalVacuumThrust"] / stagesData[currentStage]["massFlow"].
            set stageDeltaV to exhaustVelocity * ln(stagesData[currentStage]["totalMass"] / stagesData[currentStage]["endMass"]).
            set burnTime to burnTime + -stagesData[currentStage]["totalMass"] * (1 - constant:e ^ (min(stageDeltaV, requiredDeltaV) / exhaustVelocity)) / stagesData[currentStage]["massFlow"].
        }

        set requiredDeltaV to requiredDeltaV - stageDeltaV.
        set currentStage to currentStage - 1.
    }

    return burnTime.
}

local function RunPredictorCorrectorIteration
{
    set currentStage to ship:stageNum.
    set stateChangeSources["massFlow"] to stagesData[currentStage]["massFlow"].
    
    set currentAcceleration to stagesData[currentStage]["totalVacuumThrust"] / shipState["mass"].
    integrator["run"]().
    
    set targetOrbitalSpeedVector to VectorExclude(shipState["radiusVector"], shipState["velocityVector"]):normalized * sqrt(body:mu / shipState["radiusVector"]:mag).
    set aimCorrectionVector to targetOrbitalSpeedVector - shipState["velocityVector"].

    set aimCandidateVector to aimCandidateVector + aimCorrectionVector.
    if aimCorrectionVector:mag < integrator["timeStep"]
    {
        set aimVector to aimCandidateVector.
        set aimCandidateVector to targetOrbitalSpeedVector - initialVelocityVector.
        set insertionAltitude to shipState["altitude"].
        set requiredDeltaV to requiredDeltaVCandidate.
    }
}

local function GetVectorAdjustedForRotation
{
    local parameter vector, timeOffset.

    if ship:altitude < 100000
        return AngleAxis(body:angularvel:mag * constant:radtodeg * timeOffset, -body:angularvel) * vector.
    else
        return vector.
}