@lazyGlobal off.
RunOncePath("motionPrediction").
RunOncePath("calculateStaging").
clearscreen.
clearVecDraws().
wait 0.

local currentStage is ship:stageNum.
local stagesData is GetStagesData().

local shipState is CreateShipState().
local stateChangeSources is CreateStateChangeSources().
set stateChangeSources["thrustDelegate"] to { local parameter state. return state["surfaceVelocityVector"]:normalized * stagesData[currentStage]["totalVacuumThrust"]. }.
set stateChangeSources["massFlow"] to stagesData[currentStage]["massFlow"].

local landingSpot is ship:geoposition.
VecDrawArgs(
    { return landingSpot:AltitudePosition(landingSpot:terrainHeight + max(5, alt:radar / 5)). },
    { return landingSpot:position - landingSpot:AltitudePosition(landingSpot:terrainHeight + max(5, alt:radar / 5)). },
    red, "", 1, true, 0.05).

local targetCoordinates is GetTargetCoordinates().
local errorVector is V(0, 0, 0).
local normalVector is V(0, 0, 0).
local targetVector is V(0, 0, 0).
local overshoot is 0.
local sideslip is 0.

local timeStep is 8.
local clampedTimeStep is timeStep.
local simulationSteps is 0.
local timeLeft is 0.
local deltaVLeft is 0.
until ship:status = "Landed"
{
    set simulationSteps to 0.
    set timeLeft to 0.
    set deltaVLeft to 0.

    set currentStage to ship:stageNum.
    set stagesData to GetStagesData().
    UpdateShipState(shipState).
    set stateChangeSources["massFlow"] to stagesData[currentStage]["massFlow"].

    until shipState["surfaceVelocityVector"]:mag < 1 or (shipState["altitude"] - shipState["surfaceCoordinates"]:terrainHeight) < 1
    {
        until shipState["mass"] > stagesData[currentStage]["endMass"] or currentStage = 0
        {
            set currentStage to currentStage - 1.
            set shipState["mass"] to stagesData[currentStage]["totalMass"].
            set stateChangeSources["massFlow"] to stagesData[currentStage]["massFlow"].
        }

        set clampedTimeStep to Min(timeStep, shipState["surfaceVelocityVector"]:mag / shipState["engineAcceleration"]:mag).
        set clampedTimeStep to Min(clampedTimeStep, Max((shipState["mass"] - stagesData[currentStage]["endMass"]), 0.001) / stateChangeSources["massFlow"]).
        if ship:altitude < 100000
            CalculateNextStateInRotatingFrame(shipState, stateChangeSources, clampedTimeStep).
        else
            CalculateNextStateInInertialFrame(shipState, stateChangeSources, clampedTimeStep).

        set simulationSteps to simulationSteps + 1.
        set timeLeft to timeLeft + clampedTimeStep.
        set deltaVLeft to deltaVLeft + shipState["engineAcceleration"]:mag * clampedTimeStep.
    }
    set landingSpot to shipState["surfaceCoordinates"].

    clearScreen.
    print "Predicted velocity: " + Round(shipState["surfaceVelocityVector"]:mag, 2).
    print "Predicted altitude: " + Round(shipState["altitude"], 2).
    print "Predicted radar altitude: " + Round(shipState["altitude"] - shipState["surfaceCoordinates"]:terrainHeight, 2).
    print "Simulation time: " + Round(timeLeft, 2).
    print "Required delta-V: " + Round(deltaVLeft, 2).

    if targetCoordinates:lat <> 0 or targetCoordinates:lng <> 0
    {
        set targetVector to targetCoordinates:position - body:position.
        set errorVector to targetVector - shipState["radiusVector"].
        set errorVector to VectorExclude(targetVector, errorVector).

        set normalVector to VectorCrossProduct(targetVector, targetCoordinates:position).
        //make it pointing from ship to target parallel to the ground
        set targetVector to VectorExclude(targetVector, targetCoordinates:position).
        
        set overshoot to errorVector:mag * cos(VectorAngle(-errorVector, targetVector)).
        set sideslip to errorVector:mag * cos(VectorAngle(errorVector, normalVector)).

        print "Overshoot: " + Round(overshoot, 2).
        print "Side slip: " + Round(sideslip, 2).
    }

    if simulationSteps < 50
        set timeStep to max(timeStep / 2, 0.1).

    wait 0.
}

clearVecDraws().

local function GetTargetCoordinates
{
    if hasTarget and not target:IsType("Body")
        return target:geoPosition.
    
    for point in AllWaypoints()
    {
        if point:isSelected
            return point.
    }

    return LatLng(0, 0).
}