@lazyGlobal off.

local totalAccelerationVector is V(0, 0, 0).
local deltaR is V(0, 0, 0).
local halfMassFlow is 0.

global function CalculateNextStateInRotatingFrame
{
    local parameter shipState is Lexicon(), stateChangeSources is Lexicon(), timeStep is 1.
    
    set halfMassFlow to stateChangeSources["massFlow"] / 2.
    set shipState["mass"] to shipState["mass"] - halfMassFlow * timeStep.
    set totalAccelerationVector to (-stateChangeSources["thrustVector"] + stateChangeSources["externalForcesVector"]) / shipState["mass"].
    set totalAccelerationVector to totalAccelerationVector + stateChangeSources["gravitationalAccelerationVector"].

    set deltaR to shipState["velocityVector"] * timeStep + totalAccelerationVector * (timeStep ^ 2) / 2.
    set shipState["radiusVector"] to shipState["radiusVector"] + deltaR.
    set shipState["radiusVector"] to AngleAxis(body:angularvel:mag * constant:radtodeg * timeStep, -body:angularvel) * shipState["radiusVector"].
    set shipState["altitude"] to shipState["radiusVector"]:mag - body:radius.
    set shipState["surfaceCoordinates"] to body:GeopositionOf(shipState["radiusVector"] + body:position).
    set shipState["velocityVector"] to shipState["velocityVector"] + totalAccelerationVector * timeStep.
    set shipState["velocityVector"] to AngleAxis(body:angularvel:mag * constant:radtodeg * timeStep, -body:angularvel) * shipState["velocityVector"].
    set shipState["surfaceVelocityVector"] to shipState["velocityVector"] - shipState["surfaceCoordinates"]:AltitudeVelocity(shipState["altitude"]):orbit.
    
    set shipState["mass"] to shipState["mass"] - halfMassFlow * timeStep.
}

global function CalculateNextStateInInertialFrame
{    
    local parameter shipState is Lexicon(), stateChangeSources is Lexicon(), timeStep is 1.
    
    set halfMassFlow to stateChangeSources["massFlow"] / 2.
    set shipState["mass"] to shipState["mass"] - halfMassFlow * timeStep.
    set totalAccelerationVector to (-stateChangeSources["thrustVector"] + stateChangeSources["externalForcesVector"]) / shipState["mass"].
    set totalAccelerationVector to totalAccelerationVector + stateChangeSources["gravitationalAccelerationVector"].
    
    set halfMassFlow to shipState["massFlow"] / 2.
    set shipState["mass"] to shipState["mass"] - halfMassFlow * timeStep.
    set shipState["accelerationVector"] to (-shipState["thrustVector"] + shipState["externalForcesVector"]) / shipState["mass"].

    set deltaR to shipState["velocityVector"] * timeStep + totalAccelerationVector * (timeStep ^ 2) / 2.
    set shipState["radiusVector"] to shipState["radiusVector"] + deltaR.
    set shipState["altitude"] to shipState["radiusVector"]:mag - body:radius.
    set shipState["surfaceCoordinates"] to body:GeopositionOf(shipState["radiusVector"] + body:position).
    set shipState["velocityVector"] to shipState["velocityVector"] + totalAccelerationVector * timeStep.
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
        "gravitationalAccelerationVector", V(0, 0, 0),
        "massFlow", 0
    ).
 }