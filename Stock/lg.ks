@lazyGlobal off.
RunOncePath("motionPrediction").
RunOncePath("burnSimulation").
RunOncePath("calculateStaging").
RunOncePath("enginesData").
clearscreen.
clearVecDraws().
wait 0.

local currentStage is ship:stageNum.
local stagesData is GetStagesData().
local enginesData is GetRunningAverage(stagesData[currentStage]["allActiveEngines"]).

local shipState is CreateShipState().
local stateChangeSources is CreateStateChangeSources().
local integrator is CreateBurnIntegrator(shipState, stateChangeSources, stagesData, 8,
    { return shipState["surfaceVelocityVector"]:mag < 1 or (shipState["altitude"] - shipState["surfaceCoordinates"]:terrainHeight) < 1. },
    { return shipState["surfaceVelocityVector"]:mag / shipState["engineAcceleration"]:mag. }).
set stateChangeSources["thrustDelegate"] to { local parameter state. return state["surfaceVelocityVector"]:normalized * stagesData[integrator["currentStage"]]["totalVacuumThrust"]. }.
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

until ship:status = "Landed"
{
    set currentStage to ship:stageNum.
    if ship:thrust > 0 and ship:control:pilotMainThrottle = 1
    {
        set enginesData to GetRunningAverage(stagesData[currentStage]["allActiveEngines"]).
        set stagesData[currentStage]["totalVacuumThrust"] to enginesData["thrust"].
        set stagesData[currentStage]["massFlow"] to enginesData["massFlow"].
    }
    UpdateShipState(shipState).
    set stateChangeSources["massFlow"] to stagesData[currentStage]["massFlow"].

    integrator["run"]().
    set landingSpot to shipState["surfaceCoordinates"].

    clearScreen.
    print "Predicted velocity: " + Round(shipState["surfaceVelocityVector"]:mag, 2).
    print "Predicted altitude: " + Round(shipState["altitude"], 2).
    print "Predicted radar altitude: " + Round(shipState["altitude"] - shipState["surfaceCoordinates"]:terrainHeight, 2).
    print "Simulation time: " + Round(integrator["timeRequired"], 2).
    print "Required delta-V: " + Round(integrator["deltaVRequired"], 2).

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