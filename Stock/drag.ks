@lazyGlobal off.
RunOncePath("motionPrediction").
clearscreen.
wait 0.

local massFlow is 0.
local shipState is CreateShipState().

local previousTime is TimeStamp().
local currentTime is TimeStamp().
local timeStep is 1.

local subSteps is 20.
local drag is 0.
local dragCoefficient is 0.
until false
{
    clearScreen.
    print "Orbital velocity difference: " + (ship:velocity:orbit - shipState["velocityVector"]):mag.
    print "Surface velocity difference: " + (ship:velocity:surface - shipState["surfaceVelocityVector"]):mag.
    print "Position difference: " + (ship:position - body:position - shipState["radiusVector"]):mag.

    set drag to (ship:velocity:surface - shipState["surfaceVelocityVector"]):mag / (timeStep * subSteps).
    print "Drag: " + Round(drag, 3).

    set dragCoefficient to (drag * ship:mass) / (ship:q * constant:atmTokPa).
    print "Drag coefficient: " + Round(dragCoefficient, 3).

    set shipState["radiusVector"] to ship:position - body:position.
    set shipState["surfaceCoordinates"] to ship:geoPosition.
    set shipState["velocityVector"] to ship:velocity:orbit.
    set shipState["surfaceVelocityVector"] to ship:velocity:surface.
    set shipState["mass"] to ship:mass.

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
        CalculateNextStateInRotatingFrame(shipState, timeStep).
    }
}