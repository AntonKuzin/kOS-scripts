@lazyGlobal off.
clearscreen.
clearVecDraws().

local timeGuess is ship:orbit:period / 2.
local guessAdjustmentStep is timeGuess / 2.

local shipRadiusVector is PositionAt(ship, TimeStamp() + timeGuess) - body:position.
local shipVelocityVector is VelocityAt(ship, TimeStamp() + timeGuess):surface.
local errorVector is V(0, 0, 0).
local normalVector is V(0, 0, 0).
local targetRadiusVector is V(0, 0, 0).

until false
{
    set timeGuess to ship:orbit:period / 2.
    set guessAdjustmentStep to ship:orbit:period / 4.
    until guessAdjustmentStep < 1
    {
        set shipRadiusVector to PositionAt(ship, TimeStamp() + timeGuess) - body:position.
        set shipVelocityVector to VelocityAt(ship, TimeStamp() + timeGuess):surface.
        set targetRadiusVector to target:position - body:position.
        set targetRadiusVector to AngleAxis(body:angularvel:mag * constant:radtodeg * timeGuess, body:angularvel) * targetRadiusVector.
        set errorVector to targetRadiusVector - shipRadiusVector.
        set errorVector to VectorExclude(shipRadiusVector, errorVector).
        set normalVector to VectorCrossProduct(shipRadiusVector, shipVelocityVector).
        if VectorAngle(errorVector, shipVelocityVector) < 90
        {
            set timeGuess to timeGuess + guessAdjustmentStep.
        }
        else
        {
            set timeGuess to timeGuess - guessAdjustmentStep.
        }
        set guessAdjustmentStep to guessAdjustmentStep / 2.
    }

    clearScreen.
    print "Left side slip: " + Round(errorVector:mag * cos(VectorAngle(errorVector, normalVector)), 2).
    print "Ship altitude: " + Round(shipRadiusVector:mag - body:radius, 2).
    print "Target altitude: " + Round(targetRadiusVector:mag - body:radius, 2).
    print "Surface velocity: " + Round(shipVelocityVector:mag, 2).
    wait 1.
}