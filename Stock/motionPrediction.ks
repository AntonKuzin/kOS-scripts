@lazyGlobal off.

local intermediateShipState1 is CreateShipState().
local intermediateShipState2 is CreateShipState().
local intermediateShipState3 is CreateShipState().
local localGsmall is 0.
local gravitationalAccelerationVector is V(0, 0, 0).
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

    set gravitationalAccelerationVector to CalculateGravitationalAcceleration(shipState["radiusVector"]).
    set accelerationVector to -stateChangeSources["thrustVectorDelegate"]:call(shipState).
    AdvanceOneStepAhead(shipState, intermediateShipState1, stateChangeSources, timeStep / 2).

    set gravitationalAccelerationVector to (gravitationalAccelerationVector + CalculateGravitationalAcceleration(intermediateShipState1["radiusVector"])) / 2.
    set accelerationVector to (-stateChangeSources["thrustVectorDelegate"]:call(shipState) + -stateChangeSources["thrustVectorDelegate"]:call(intermediateShipState1)) / 2.
    AdvanceOneStepAhead(shipState, intermediateShipState2, stateChangeSources, timeStep / 2).

    set gravitationalAccelerationVector to (CalculateGravitationalAcceleration(shipState["radiusVector"]) + CalculateGravitationalAcceleration(intermediateShipState2["radiusVector"])) / 2.
    set accelerationVector to (-stateChangeSources["thrustVectorDelegate"]:call(shipState) + -stateChangeSources["thrustVectorDelegate"]:call(intermediateShipState2)) / 2.
    AdvanceOneStepAhead(shipState, intermediateShipState3, stateChangeSources, timeStep).

    set gravitationalAccelerationVector to (CalculateGravitationalAcceleration(shipState["radiusVector"])
        + 2 * CalculateGravitationalAcceleration(intermediateShipState1["radiusVector"])
        + 2 * CalculateGravitationalAcceleration(intermediateShipState2["radiusVector"])
        + CalculateGravitationalAcceleration(intermediateShipState3["radiusVector"])) / 6.
    set accelerationVector to (-stateChangeSources["thrustVectorDelegate"]:call(shipState)
        + 2 * -stateChangeSources["thrustVectorDelegate"]:call(intermediateShipState1)
        + 2 * -stateChangeSources["thrustVectorDelegate"]:call(intermediateShipState2)
        + -stateChangeSources["thrustVectorDelegate"]:call(intermediateShipState3)) / 6.
    AdvanceOneStepAhead(shipState, shipState, stateChangeSources, timeStep).
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
        "thrustVectorDelegate", V(0, 0, 0),
        "externalForcesVector", V(0, 0, 0),
        "massFlow", 0
    ).
 }

 local function AdvanceOneStepAhead
 {
    local parameter sourceShipState is Lexicon(), destinationShipState is Lexicon(), stateChangeSources is Lexicon(), timeStep is 1.

    set halfMassFlow to stateChangeSources["massFlow"] / 2.
    set destinationShipState["mass"] to sourceShipState["mass"] - halfMassFlow * timeStep.
    set accelerationVector to (accelerationVector + stateChangeSources["externalForcesVector"]) / destinationShipState["mass"].

    set deltaR to sourceShipState["velocityVector"] * timeStep + (accelerationVector + gravitationalAccelerationVector) * (timeStep ^ 2) / 2.

    set destinationShipState["radiusVector"] to sourceShipState["radiusVector"] + deltaR.
    set destinationShipState["altitude"] to destinationShipState["radiusVector"]:mag - body:radius.
    set destinationShipState["surfaceCoordinates"] to body:GeopositionOf(destinationShipState["radiusVector"] + body:position).
    set destinationShipState["velocityVector"] to sourceShipState["velocityVector"] + (accelerationVector + gravitationalAccelerationVector) * timeStep.
    set destinationShipState["surfaceVelocityVector"] to destinationShipState["velocityVector"] - destinationShipState["surfaceCoordinates"]:AltitudeVelocity(destinationShipState["altitude"]):orbit.
    
    set destinationShipState["mass"] to destinationShipState["mass"] - halfMassFlow * timeStep.
 }

 local function CalculateGravitationalAcceleration
 {
    local parameter radiusVector is V(1, 0, 0).

    set localGsmall to body:mu / radiusVector:mag ^ 2.
    return -radiusVector:normalized * localGsmall.
 }