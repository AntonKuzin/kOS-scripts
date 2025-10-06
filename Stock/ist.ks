@lazyGlobal off.
clearscreen.
clearVecDraws().
RunOncePath("motionPrediction").

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
local ISP is thrust / constant:g0 / maxMassFlow.

local timeStep is 0.
local timeGuess is ship:orbit:period / 4.
local guessAdjustmentStep is timeGuess / 2.

local shipState is Lexicon(
    "radiusVector", PositionAt(ship, TimeStamp() + timeGuess) - body:position,
    "surfaceCoordinates", ship:geoPosition,
    "velocityVector", VelocityAt(ship, TimeStamp() + timeGuess):orbit,
    "surfaceVelocityVector", VelocityAt(ship, TimeStamp() + timeGuess):surface,
    "mass", ship:mass,
    "thrustVector", V(0, 0, 0),
    "accelerationVector", V(0, 0, 0),
    "ISP", ISP).

set timeStep to 1.
local landingSpot is ship:geoposition.
VecDrawArgs(
    { return landingSpot:AltitudePosition(landingSpot:terrainHeight + max(20, (shipState["radiusVector"] + body:position):mag / 10)). },
    { return landingSpot:position - landingSpot:AltitudePosition(landingSpot:terrainHeight + max(20, (shipState["radiusVector"] + body:position):mag / 10)). },
    red, "Here", 1, true).

local targetCoordinates is GetTargetCoordinates().
local errorVector is V(0, 0, 0).
local normalVector is V(0, 0, 0).
local targetVector is V(0, 0, 0).
local overshoot is 0.
local sideslip is 0.

local initialShipSpeedVector is shipState["surfaceVelocityVector"].
local ititialTime is TimeStamp().

local simulationSteps is 0.
local timeLeft is 0.
local deltaVLeft is 0.
until false
{
    set simulationSteps to 0.
    set timeLeft to 0.
    set deltaVLeft to 0.

    set shipState["mass"] to ship:mass.
    set shipState["radiusVector"] to PositionAt(ship, ititialTime + timeGuess) - body:position.
    set shipState["velocityVector"] to VelocityAt(ship, ititialTime + timeGuess):orbit.
    set shipState["surfaceVelocityVector"] to VelocityAt(ship, ititialTime + timeGuess):surface.
    set shipState["radiusVector"] to AngleAxis(body:angularvel:mag * constant:radtodeg * timeGuess, -body:angularvel) * shipState["radiusVector"].
    set shipState["velocityVector"] to AngleAxis(body:angularvel:mag * constant:radtodeg * timeGuess, -body:angularvel) * shipState["velocityVector"].
    set shipState["surfaceVelocityVector"] to AngleAxis(body:angularvel:mag * constant:radtodeg * timeGuess, -body:angularvel) * shipState["surfaceVelocityVector"].

    set initialShipSpeedVector to shipState["velocityVector"].
    set targetVector to targetCoordinates:position - body:position.

    set shipState["thrustVector"] to SHIP:FACING * V(0, 0, -ship:thrust).

    until shipState["surfaceVelocityVector"]:mag < shipState["accelerationVector"]:mag * timeStep or (shipState["radiusVector"]:mag - body:radius - shipState["surfaceCoordinates"]:terrainHeight) < 1
    {
        if ship:altitude < 100000
            CalculateNextPositionInRotatingFrame(shipState, timeStep).
        else
            CalculateNextPositionInInertialFrame(shipState, timeStep).

        set simulationSteps to simulationSteps + 1.
        set timeLeft to timeLeft + timeStep.
        set deltaVLeft to deltaVLeft + shipState["accelerationVector"]:mag * timeStep.
        set shipState["thrustVector"] to shipState["surfaceVelocityVector"]:normalized * thrust.
    }
    
    set errorVector to targetVector - shipState["radiusVector"].
    set errorVector to VectorExclude(targetVector, errorVector).

    set normalVector to VectorCrossProduct(targetVector, initialShipSpeedVector).
    //make it pointing from ship to target parallel to the ground
    set targetVector to VectorExclude(targetVector, initialShipSpeedVector).
    
    set overshoot to errorVector:mag * cos(VectorAngle(-errorVector, targetVector)).
    set sideslip to errorVector:mag * cos(VectorAngle(errorVector, normalVector)).

    if guessAdjustmentStep < 0.1
    {
        set landingSpot to shipState["surfaceCoordinates"].
        set ititialTime to TimeStamp().
        set guessAdjustmentStep to 10.
        
        clearScreen.
        print "Predicted velocity: " + Round(shipState["surfaceVelocityVector"]:mag, 2).
        print "Predicted altitude: " + Round((shipState["radiusVector"]:mag - body:radius), 2).
        print "Predicted radar altitude: " + Round((shipState["radiusVector"]:mag - body:radius - shipState["surfaceCoordinates"]:terrainHeight), 2).
        print "Simulation time: " + Round(timeLeft, 2).
        print "Required delta-V: " + Round(deltaVLeft, 2).
        print "Overshoot: " + Round(overshoot, 2).
        print "Left side slip: " + Round(sideslip, 2).
    }
    else if overshoot > 0
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

    if hasTarget
        return target:geoPosition.    

    return LatLng(0, 0).
}