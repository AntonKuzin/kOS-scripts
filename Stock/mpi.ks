@lazyGlobal off.
RunOncePath("motionPrediction").
clearscreen.
wait 0.

local massFlow is 0.
FOR engine in ship:engines
{
    set massFlow to massFlow + engine:massFlow.
}

local shipState is Lexicon(
    "radiusVector", ship:position - body:position,
    "surfaceCoordinates", ship:geoPosition,
    "velocityVector", ship:velocity:orbit,
    "surfaceVelocityVector", ship:velocity:surface,
    "mass", ship:mass,
    "thrustVector", V(0, 0, 0),
    "accelerationVector", V(0, 0, 0),
    "massFlow", massFlow).

local previousTime is TimeStamp().
local currentTime is TimeStamp().
local timeStep is (currentTime - previousTime):seconds.

local subSteps is 10.
until ship:altitude < 100000
{
    clearScreen.
    print "Orbital velocity difference: " + (ship:velocity:orbit - shipState["velocityVector"]):mag.
    print "Surface velocity difference: " + (ship:velocity:surface - shipState["surfaceVelocityVector"]):mag.
    print "Position difference: " + (ship:position - body:position - shipState["radiusVector"]):mag.

    set massFlow to 0.
    FOR engine in ship:engines
    {
        set massFlow to massFlow + engine:massFlow.
    }
    set shipState["massFlow"] to massFlow.
    set shipState["thrustVector"] to SHIP:FACING * V(0, 0, -ship:thrust).

    set previousTime to currentTime.
    wait 0.
    set currentTime to TimeStamp().
    set timeStep to (currentTime - previousTime):seconds / substeps.

    FROM {local i is substeps.} UNTIL i = 0 STEP {set i to i-1.} DO
    {
        CalculateNextStateInInertialFrame(shipState, timeStep).
    }
}

RunPath("mpr").