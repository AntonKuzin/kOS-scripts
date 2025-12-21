@lazyGlobal off.
RunOncePath("calculateStaging").
RunOncePath("motionPrediction").
clearScreen.

set ship:control:pilotMainThrottle to 0.
lock steering to ship:velocity:surface.
local stagesData is GetStagesData().
local shipState is CreateShipState().

local burnStartTime is TimeStamp() + eta:apoapsis.
local initialVelocityVector is GetVectorAdjustedForRotation(VelocityAt(ship, burnStartTime):orbit, eta:apoapsis).
local targetOrbitalSpeedVector is initialVelocityVector:normalized * sqrt(body:mu / (PositionAt(ship, burnStartTime) - body:position):mag).

local aimVector is targetOrbitalSpeedVector - initialVelocityVector.

local requiredDeltaV is aimVector:mag.
local burnTime is GetBurnTime(requiredDeltaV).
set burnStartTime to burnStartTime - burnTime / 2.

local timeStep is 1.
local integrationSteps is 0.
until TimeStamp():seconds > burnStartTime
{
    UpdateShipState(shipState).
    set shipState["radiusVector"] to GetVectorAdjustedForRotation(PositionAt(ship, burnStartTime) - body:position, eta:apoapsis - burnTime / 2).
    set shipState["velocityVector"] to GetVectorAdjustedForRotation(VelocityAt(ship, burnStartTime):orbit, eta:apoapsis - burnTime / 2).
    set shipState["surfaceVelocityVector"] to GetVectorAdjustedForRotation(VelocityAt(ship, burnStartTime):surface, eta:apoapsis - burnTime / 2).

    RunPredictorCorrectorIteration().

    set requiredDeltaV to aimVector:mag.
    set burnTime to GetBurnTime(requiredDeltaV).

    clearScreen.
    print "Coasting to apoapsis: " + Round(eta:apoapsis - (burnTime / 2), 2).
    print "DeltaV to burn: " + Round(requiredDeltaV, 2).
    print "Orbital insertion altitude: " + Round(shipState["altitude"], 0).

    wait 1.
}

lock steering to aimVector.
set ship:control:pilotMainThrottle to 1.
wait until ship:thrust > 0.

local acceleration is ship:thrust / ship:mass.
until targetOrbitalSpeedVector:mag < velocity:orbit:mag
{
    if ship:thrust = 0
    {
        stage.
        wait until ship:thrust > 0.
    }

    UpdateShipState(shipState).
    RunPredictorCorrectorIteration().

    set acceleration to ship:thrust / ship:mass. 
    if (targetOrbitalSpeedVector - ship:velocity:orbit):mag <= acceleration
    {
        set ship:control:pilotMainThrottle to max(0.01, ship:control:pilotMainThrottle / 2).
    }

    clearScreen.
    print "Orbital insertion".
    print "DeltaV to burn: " + Round((targetOrbitalSpeedVector - ship:velocity:orbit):mag, 2).
    print "Insertion altitude: " + Round(shipState["altitude"], 0).

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
    local currentStage is ship:stageNum.

    set shipState["massFlow"] to stagesData[currentStage]["massFlow"].
    set shipState["thrustVector"] to -aimVector:normalized * stagesData[currentStage]["totalVacuumThrust"].
    set initialVelocityVector to shipState["velocityVector"].
    
    set integrationSteps to 0.
    until shipState["velocityVector"]:mag >= targetOrbitalSpeedVector:mag and shipState["mass"] >= stagesData[0]["endMass"]
    {
        until shipState["mass"] > stagesData[currentStage]["endMass"] or currentStage = 0
        {
            set currentStage to currentStage - 1.
            set shipState["mass"] to stagesData[currentStage]["totalMass"].
            set shipState["massFlow"] to stagesData[currentStage]["massFlow"].
            set shipState["thrustVector"] to -aimVector:normalized * stagesData[currentStage]["totalVacuumThrust"].
        }

        CalculateNextStateInRotatingFrame(shipState, timeStep).
        
        set integrationSteps to integrationSteps + 1.
    }
    set shipState["velocityVector"]:mag to targetOrbitalSpeedVector:mag.

    if integrationSteps < 100
    {
        set timeStep to Max(0.05, timeStep / 2).
    }
    
    set targetOrbitalSpeedVector to VectorExclude(shipState["radiusVector"], shipState["velocityVector"]):normalized * sqrt(body:mu / shipState["radiusVector"]:mag).
    set aimVector to aimVector + (targetOrbitalSpeedVector - shipState["velocityVector"]).
}

local function GetVectorAdjustedForRotation
{
    local parameter vector, timeOffset.

    return AngleAxis(body:angularvel:mag * constant:radtodeg * timeOffset, -body:angularvel) * vector.
}