@lazyGlobal off.

local localGsmall is 0.
local gravityVector is V(0, 0, 0).
local deltaR is V(0, 0, 0).
local halfMassFlow is 0.

global function CalculateNextPositionInRotatingFrame
{
    parameter shipState is Lexicon, timeStep is 1.
    
    set localGsmall to body:mu / shipState["radiusVector"]:mag ^ 2.
    set gravityVector to -shipState["radiusVector"]:normalized * localGsmall.
    
    set halfMassFlow to shipState["massFlow"] / 2.
    set shipState["mass"] to shipState["mass"] - halfMassFlow * timeStep.
    set shipState["accelerationVector"] to -shipState["thrustVector"] / shipState["mass"].

    set deltaR to shipState["surfaceVelocityVector"] * timeStep + (shipState["accelerationVector"] + gravityVector) * (timeStep ^ 2) / 2.
    set shipState["radiusVector"] to shipState["radiusVector"] + deltaR.
    set shipState["surfaceCoordinates"] to body:GeopositionOf(shipState["radiusVector"] + body:position).
    set shipState["velocityVector"] to shipState["velocityVector"] + (shipState["accelerationVector"] + gravityVector) * timeStep.
    set shipState["velocityVector"] to AngleAxis(body:angularvel:mag * constant:radtodeg * timeStep, -body:angularvel) * shipState["velocityVector"].
    set shipState["surfaceVelocityVector"] to shipState["velocityVector"] + -shipState["surfaceCoordinates"]:AltitudeVelocity(shipState["radiusVector"]:mag - body:radius):orbit.
    
    set shipState["mass"] to shipState["mass"] - halfMassFlow * timeStep.
}

global function CalculateNextPositionInInertialFrame
{
    parameter shipState is Lexicon, timeStep is 1.
    
    set localGsmall to body:mu / shipState["radiusVector"]:mag ^ 2.
    set gravityVector to -shipState["radiusVector"]:normalized * localGsmall.
    
    set halfMassFlow to shipState["massFlow"] / 2.
    set shipState["mass"] to shipState["mass"] - halfMassFlow * timeStep.
    set shipState["accelerationVector"] to -shipState["thrustVector"] / shipState["mass"].

    set deltaR to shipState["velocityVector"] * timeStep + (shipState["accelerationVector"] + gravityVector) * (timeStep ^ 2) / 2.
    set shipState["radiusVector"] to shipState["radiusVector"] + deltaR.
    set shipState["surfaceCoordinates"] to body:GeopositionOf(shipState["radiusVector"] + body:position).
    set shipState["velocityVector"] to shipState["velocityVector"] + (shipState["accelerationVector"] + gravityVector) * timeStep.
    set shipState["surfaceVelocityVector"] to shipState["velocityVector"] + -shipState["surfaceCoordinates"]:AltitudeVelocity(shipState["radiusVector"]:mag - body:radius):orbit.
    
    set shipState["mass"] to shipState["mass"] - halfMassFlow * timeStep.
}

 global function CreateShipState
 {
    return Lexicon(
        "radiusVector", ship:position - body:position,
        "surfaceCoordinates", ship:geoPosition,
        "velocityVector", ship:velocity:orbit,
        "surfaceVelocityVector", ship:velocity:surface,
        "mass", ship:mass,
        "thrustVector", V(0, 0, 0),
        "accelerationVector", V(0, 0, 0),
        "massFlow", 0).
 }   