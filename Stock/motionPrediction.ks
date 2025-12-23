@lazyGlobal off.

local localGsmall is 0.
local gravitationalAccelerationVector is V(0, 0, 0).
local intermediateRadiusVector is V(0, 0, 0).
local accelerationVector is V(0, 0, 0).
local deltaR is V(0, 0, 0).
local halfMassFlow is 0.

global function CalculateNextStateInRotatingFrame
{
    local parameter shipState is Lexicon(), stateChangeSources is Lexicon(), timeStep is 1.

    CalculateNextStateInInertialFrame(shipState, stateChangeSources, timeStep).
    set shipState["radiusVector"] to AngleAxis(body:angularvel:mag * constant:radtodeg * timeStep, -body:angularvel) * shipState["radiusVector"].
    set shipState["velocityVector"] to AngleAxis(body:angularvel:mag * constant:radtodeg * timeStep, -body:angularvel) * shipState["velocityVector"].
    set shipState["surfaceVelocityVector"] to AngleAxis(body:angularvel:mag * constant:radtodeg * timeStep, -body:angularvel) * shipState["surfaceVelocityVector"].
}

global function CalculateNextStateInInertialFrame
{    
    local parameter shipState is Lexicon(), stateChangeSources is Lexicon(), timeStep is 1.
    
    set halfMassFlow to stateChangeSources["massFlow"] / 2.
    set shipState["mass"] to shipState["mass"] - halfMassFlow * timeStep.
    set accelerationVector to (-stateChangeSources["thrustVector"] + stateChangeSources["externalForcesVector"]) / shipState["mass"].

    set localGsmall to body:mu / shipState["radiusVector"]:mag ^ 2.
    set gravitationalAccelerationVector to -shipState["radiusVector"]:normalized * localGsmall.
    set deltaR to shipState["velocityVector"] * timeStep + (accelerationVector + gravitationalAccelerationVector) * (timeStep ^ 2) / 2.
    set intermediateRadiusVector to shipState["radiusVector"] + deltaR.
    set localGsmall to body:mu / intermediateRadiusVector:mag ^ 2.
    set gravitationalAccelerationVector to (gravitationalAccelerationVector + -intermediateRadiusVector:normalized * localGsmall) / 2.

    set deltaR to shipState["velocityVector"] * timeStep + (accelerationVector + gravitationalAccelerationVector) * (timeStep ^ 2) / 2.
    set shipState["radiusVector"] to shipState["radiusVector"] + deltaR.
    set shipState["altitude"] to shipState["radiusVector"]:mag - body:radius.
    set shipState["surfaceCoordinates"] to body:GeopositionOf(shipState["radiusVector"] + body:position).
    set shipState["velocityVector"] to shipState["velocityVector"] + (accelerationVector + gravitationalAccelerationVector) * timeStep.
    set shipState["surfaceVelocityVector"] to shipState["velocityVector"] - shipState["surfaceCoordinates"]:AltitudeVelocity(shipState["altitude"]):orbit.
    
    set shipState["mass"] to shipState["mass"] - halfMassFlow * timeStep.
}

 global function CreateShipState
 {
    return Lexicon(
        "radiusVector", ship:position - body:position,
        "altitude", ship:altitude,
        "surfaceCoordinates", ship:geoPosition,
        "velocityVector", ship:velocity:orbit,
        "surfaceVelocityVector", ship:velocity:surface,
        "mass", ship:mass
    ).
 }

 global function UpdateShipState
 {
    local parameter shipState is Lexicon().

    set shipState["radiusVector"] to ship:position - body:position.
    set shipState["altitude"] to ship:altitude.
    set shipState["surfaceCoordinates"] to ship:geoPosition.
    set shipState["velocityVector"] to ship:velocity:orbit.
    set shipState["surfaceVelocityVector"] to ship:velocity:surface.
    set shipState["mass"] to ship:mass.
 }

 global function CreateStateChangeSources
 {
    return Lexicon(
        "thrustVector", V(0, 0, 0),
        "externalForcesVector", V(0, 0, 0),
        "massFlow", 0
    ).
 }