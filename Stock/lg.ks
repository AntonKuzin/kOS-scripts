@lazyGlobal off.
RunOncePath("motionPrediction").
clearscreen.
clearVecDraws().
wait 0.

local engines is ship:engines.
local maxMassFlow is 0.
FOR engine in engines
{
    if engine:ignition
    {
        set maxMassFlow to maxMassFlow + engine:maxMassFlow * engine:thrustLimit / 100.
    }
}

local perceivedAcceleration is 0.
local shipState is Lexicon(
    "radiusVector", ship:position - body:position,
    "surfaceCoordinates", ship:geoPosition,
    "velocityVector", ship:velocity:orbit,
    "surfaceVelocityVector", ship:velocity:surface,
    "mass", ship:mass,
    "thrustVector", V(0, 0, 0),
    "accelerationVector", V(0, 0, 0),
    "massFlow", maxMassFlow).

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

local timeStep is 1.
local simulationSteps is 0.
local timeLeft is 0.
local deltaVLeft is 0.
until false
{
    set simulationSteps to 0.
    set timeLeft to 0.
    set deltaVLeft to 0.

    set shipState["mass"] to ship:mass.
    set shipState["radiusVector"] to ship:position - body:position.
    set shipState["velocityVector"] to velocity:orbit.
    set shipState["surfaceVelocityVector"] to velocity:surface.

    set perceivedAcceleration to ship:thrust / ship:mass.
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
    set landingSpot to shipState["surfaceCoordinates"].

    clearScreen.
    print "Predicted velocity: " + Round(shipState["surfaceVelocityVector"]:mag, 2).
    print "Predicted altitude: " + Round((shipState["radiusVector"]:mag - body:radius), 2).
    print "Predicted radar altitude: " + Round((shipState["radiusVector"]:mag - body:radius - shipState["surfaceCoordinates"]:terrainHeight), 2).
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
        print "Left side slip: " + Round(sideslip, 2).
    }

    if perceivedAcceleration > 0.5 and  simulationSteps < 200
        set timeStep to max(timeStep / 2, 0.05).

    wait 0.
}

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