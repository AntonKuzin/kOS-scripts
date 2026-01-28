@lazyGlobal off.
RunOncePath("motionPrediction").
RunOncePath("calculateStaging").
RunOncePath("burnSimulation").
clearscreen.
clearVecDraws().

local timeGuess is ship:orbit:period / 4.
local guessAdjustmentStep is timeGuess / 2.

local currentStage is ship:stageNum.
local stagesData is GetStagesData().

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
local searchCriterion is DoNothing.
local printAdditionalInfo is DoNothing.
local resetSearchParameters is DoNothing.
if targetCoordinates:LAT <> 0 and targetCoordinates:LNG <> 0
{
    set searchCriterion to CheckDistance@.
    set printAdditionalInfo to PrintTargetAimingInfo@.
    set resetSearchParameters to AdjustExistingSolution@.
}
else
{
    set searchCriterion to CheckAltitude@.
    set resetSearchParameters to StartFromScratch@.
}

local errorVector is V(0, 0, 0).
local normalVector is V(0, 0, 0).
local targetVector is V(0, 0, 0).
local overshoot is 0.
local sideslip is 0.

local initialShipSpeedVector is shipState["velocityVector"].
local ititialTime is TimeStamp().

until false
{
    set currentStage to ship:stageNum.
    //set stagesData to GetStagesData().
    set stateChangeSources["massFlow"] to stagesData[currentStage]["massFlow"].

    set shipState["mass"] to ship:mass.
    set shipState["radiusVector"] to PositionAt(ship, ititialTime + timeGuess) - body:position.
    set shipState["velocityVector"] to VelocityAt(ship, ititialTime + timeGuess):orbit.
    set shipState["surfaceVelocityVector"] to VelocityAt(ship, ititialTime + timeGuess):surface.
    set shipState["radiusVector"] to AngleAxis(body:angularvel:mag * constant:radtodeg * timeGuess, -body:angularvel) * shipState["radiusVector"].
    set shipState["velocityVector"] to AngleAxis(body:angularvel:mag * constant:radtodeg * timeGuess, -body:angularvel) * shipState["velocityVector"].
    set shipState["surfaceVelocityVector"] to AngleAxis(body:angularvel:mag * constant:radtodeg * timeGuess, -body:angularvel) * shipState["surfaceVelocityVector"].
    set shipState["altitude"] to shipState["radiusVector"]:mag - body:radius.

    set initialShipSpeedVector to shipState["velocityVector"].
    set targetVector to targetCoordinates:position - body:position.
    integrator["run"]().

    if guessAdjustmentStep < 0.1
    {
        clearScreen.
        print "Predicted velocity: " + Round(shipState["surfaceVelocityVector"]:mag, 2).
        print "Predicted altitude: " + Round(shipState["altitude"], 2).
        print "Predicted radar altitude: " + Round((shipState["altitude"] - shipState["surfaceCoordinates"]:terrainHeight), 2).
        print "Simulation time: " + Round(integrator["timeRequired"], 2).
        print "Required delta-V: " + Round(integrator["deltaVRequired"], 2).
        print "PDI in: " + Round(timeGuess, 2).
        printAdditionalInfo:call().
        
        set landingSpot to shipState["surfaceCoordinates"].
        set ititialTime to TimeStamp().
        resetSearchParameters:call().
    }
    else if searchCriterion:call()
    {
        set timeGuess to timeGuess - guessAdjustmentStep.
    }
    else
    {
        set timeGuess to timeGuess + guessAdjustmentStep.
    }
    set guessAdjustmentStep to guessAdjustmentStep / 2.

    wait 0.
}

local function GetTargetCoordinates
{
    for point in AllWaypoints()
    {
        if point:isSelected
            return point:geoPosition.
    }

    if hasTarget and not target:IsType("Body")
        return target:geoPosition.    

    return LatLng(0, 0).
}

local function CheckAltitude
{
    return shipState["altitude"] < shipState["surfaceCoordinates"]:terrainHeight
        or timeGuess > orbit:period / 2.
}

local function CheckDistance
{
    set errorVector to targetVector - shipState["radiusVector"].
    set errorVector to VectorExclude(targetVector, errorVector).

    set normalVector to VectorCrossProduct(targetVector, initialShipSpeedVector).
    //make it pointing from ship to target parallel to the ground
    set targetVector to VectorExclude(targetVector, initialShipSpeedVector).
    
    set overshoot to errorVector:mag * cos(VectorAngle(-errorVector, targetVector)).
    set sideslip to errorVector:mag * cos(VectorAngle(errorVector, normalVector)).
    return overshoot > 0.
}

local function PrintTargetAimingInfo
{
    print "Overshoot: " + Round(overshoot, 2).
    print "Side slip: " + Round(sideslip, 2).
}

local function StartFromScratch
{
    set guessAdjustmentStep to ship:orbit:period / 16.
}

local function AdjustExistingSolution
{
    set guessAdjustmentStep to 10.
}