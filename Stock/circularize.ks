@lazyGlobal off.
clearScreen.

local thrust is 0.
local maxMassFlow is 0.
local exhaustVelocity is 0.
FOR engine in ship:engines
{
    if engine:ignition
    {
        set thrust to thrust + engine:possibleThrust.
        set maxMassFlow to maxMassFlow + engine:maxMassFlow * engine:thrustLimit / 100.
    }
}
set exhaustVelocity to thrust / maxMassFlow.

local targetHorizontalSpeedVector is VectorExclude(body:position, velocity:orbit):normalized * sqrt(body:mu / body:position:mag).
local aimVector is targetHorizontalSpeedVector - velocity:orbit.
local burnTime is -ship:mass * (1 - constant:e ^ (aimVector:mag / exhaustVelocity)) / maxMassFlow.

lock steering to aimVector.

until eta:apoapsis < burnTime / 2
{
    clearScreen.
    print "Coasting to apoapsis: " + Round(eta:apoapsis - (burnTime / 2), 2).
    print "DeltaV to burn: " + Round(aimVector:mag, 2).

    set targetHorizontalSpeedVector to VectorExclude(body:position, velocity:orbit):normalized * sqrt(body:mu / body:position:mag).
    set aimVector to targetHorizontalSpeedVector - velocity:orbit.
    set burnTime to -ship:mass * (1 - constant:e ^ (aimVector:mag / exhaustVelocity)) / maxMassFlow.

    wait 1.
}

set ship:control:pilotMainThrottle to 1.
wait until ship:thrust > 0.

local acceleration is ship:thrust / ship:mass.
until aimVector:mag < 0.01
{
    clearScreen.
    print "DeltaV to burn: " + Round(aimVector:mag, 2).
    
    set acceleration to ship:thrust / ship:mass.
    set ship:control:pilotMainThrottle to min(1, aimVector:mag / acceleration / 10).

    set targetHorizontalSpeedVector to VectorExclude(body:position, velocity:orbit):normalized * sqrt(body:mu / body:position:mag).
    set aimVector to targetHorizontalSpeedVector - velocity:orbit.

    wait 0.
}

set ship:control:pilotMainThrottle to 0.
unlock steering.