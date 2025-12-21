@lazyGlobal off.
RunOncePath("motionPrediction").
clearscreen.
clearVecDraws().
wait 0.

local engines is ship:engines.
local thrust is 0.
local maxMassFlow is 0.
FOR engine in engines
{
    if engine:ignition
    {
        set thrust to thrust + engine:possibleThrust.
        set maxMassFlow to maxMassFlow + engine:maxMassFlow * engine:thrustLimit / 100.
    }
}

local currentAcceleration is thrust / ship:mass.
local shipState is CreateShipState().
local auxiliaryShipState is CreateShipState().
local stateChangeSources is CreateStateChangeSources().
set stateChangeSources["massFlow"] to maxMassFlow.
local localGsmall is body:mu / shipState["radiusVector"]:mag ^ 2.
set stateChangeSources["gravitationalAccelerationVector"] to -shipState["radiusVector"]:normalized * localGsmall.

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

local timeStep is 4.
local clampedTimeStep is timeStep.
local simulationSteps is 0.
local timeLeft is 0.
until ship:status = "Landed"
{
    set simulationSteps to 0.
    set timeLeft to 0.

    UpdateShipState(shipState).
    set currentAcceleration to thrust / shipState["mass"].

    UpdateShipState(auxiliaryShipState).
    set stateChangeSources["thrustVector"] to SHIP:FACING * V(0, 0, -ship:thrust).
    set localGsmall to body:mu / shipState["radiusVector"]:mag ^ 2.
    set stateChangeSources["gravitationalAccelerationVector"] to -auxiliaryShipState["radiusVector"]:normalized * localGsmall.

    until shipState["surfaceVelocityVector"]:mag < 1 or (shipState["altitude"] - shipState["surfaceCoordinates"]:terrainHeight) < 1
    {
        set clampedTimeStep to Min(timeStep, shipState["surfaceVelocityVector"]:mag / currentAcceleration).
        if ship:altitude < 100000
        {
            CalculateNextStateInRotatingFrame(auxiliaryShipState, stateChangeSources, clampedTimeStep / 2).
            set stateChangeSources["thrustVector"] to auxiliaryShipState["surfaceVelocityVector"]:normalized * thrust.
            set localGsmall to body:mu / auxiliaryShipState["radiusVector"]:mag ^ 2.
            set stateChangeSources["gravitationalAccelerationVector"] to -auxiliaryShipState["radiusVector"]:normalized * localGsmall.
            CalculateNextStateInRotatingFrame(shipState, stateChangeSources, clampedTimeStep).
            set auxiliaryShipState["mass"] to shipState["mass"].
            set auxiliaryShipState["altitude"] to shipState["altitude"].
            set auxiliaryShipState["surfaceCoordinates"] to shipState["surfaceCoordinates"].
            set auxiliaryShipState["radiusVector"] to shipState["radiusVector"].
            set auxiliaryShipState["surfaceVelocityVector"] to shipState["surfaceVelocityVector"].
            set auxiliaryShipState["velocityVector"] to shipState["velocityVector"].
        }
        else
            CalculateNextStateInInertialFrame(shipState, timeStep).

        set currentAcceleration to thrust / shipState["mass"].
        set stateChangeSources["thrustVector"] to shipState["surfaceVelocityVector"]:normalized * thrust.
        set localGsmall to body:mu / shipState["radiusVector"]:mag ^ 2.
        set stateChangeSources["gravitationalAccelerationVector"] to -shipState["radiusVector"]:normalized * localGsmall.

        set simulationSteps to simulationSteps + 1.
        set timeLeft to timeLeft + clampedTimeStep.
    }
    set landingSpot to shipState["surfaceCoordinates"].

    clearScreen.
    print "Predicted velocity: " + Round(shipState["surfaceVelocityVector"]:mag, 2).
    print "Predicted altitude: " + Round(shipState["altitude"], 2).
    print "Predicted radar altitude: " + Round(shipState["altitude"] - shipState["surfaceCoordinates"]:terrainHeight, 2).
    print "Simulation time: " + Round(timeLeft, 2).

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

    if simulationSteps < 100
        set timeStep to max(timeStep / 2, 0.05).

    wait 0.
}

clearVecDraws().

local function GetTargetCoordinates
{
    if hasTarget
        return target:geoPosition.
    
    for point in AllWaypoints()
    {
        if point:isSelected
            return point.
    }

    return LatLng(0, 0).
}