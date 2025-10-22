@lazyGlobal off.
RunOncePath("calculateStaging").
RunOncePath("motionPrediction").
clearVecDraws().

local parameter LAN is -1.
local parameter inclination is orbit:inclination.

if LAN <> -1
{
    local launchTimeOffset is 60.
    local targetAngularDifference is ArcSin(tan(orbit:inclination) / tan(inclination)).
    local launchOnAscendingPass is 1.
    local headingOffset is 90 - ArcSin(Cos(inclination) / Cos(orbit:inclination)).

    local targetANVector is AngleAxis(LAN, -Sun:Up:topVector) * solarPrimeVector.
    local equatorialPlaneVector is vectorExclude(-Sun:Up:topVector, ship:position - body:position).
    local currentAngularDifference is VectorAngle(targetANVector, equatorialPlaneVector).
    local timeToWait is (currentAngularDifference - launchOnAscendingPass * targetAngularDifference) / (body:angularvel:mag * constant:radtodeg).
    local previousTimeToWait is timeToWait.

    until timeToWait <= launchTimeOffset
    {
        set targetANVector to AngleAxis(LAN, -Sun:Up:topVector) * solarPrimeVector.
        set equatorialPlaneVector to vectorExclude(-Sun:Up:topVector, ship:position - body:position).
        set currentAngularDifference to VectorAngle(targetANVector, equatorialPlaneVector).
        set timeToWait to (currentAngularDifference - launchOnAscendingPass * targetAngularDifference) / (body:angularvel:mag * constant:radtodeg).

        clearScreen.
        print "Time to wait: " + Round(timeToWait - launchTimeOffset, 0).
        print "Heading: " + Round(90 - launchOnAscendingPass * headingOffset, 1).

        if timeToWait > previousTimeToWait
        {
            set timeToWait to 1e9.
            set LAN to LAN + 180.
            set launchOnAscendingPass to launchOnAscendingPass * -1.
        }
        set previousTimeToWait to timeToWait.

        wait min(1, timeToWait - launchTimeOffset).
    }
}

local parameter targetAltitude is 75000.
local timeStep is 1.

local stagesData is GetStagesData().
local shipState is CreateShipState().
local predictedOrbit is CREATEORBIT(-body:position, velocity:orbit, body, 0).

local currentStage is ship:stageNum.
until orbit:apoapsis >= targetAltitude
{
    if currentStage > ship:stageNum
    {
        set currentStage to ship:stageNum.
        wait until stage:ready.
        set stagesData to GetStagesData().
    }
    set currentStage to ship:stageNum.
    
    set shipState to CreateShipState().
    set shipState["thrustVector"] to ship:facing * V(0, 0, -GetEnginesThrust(stagesData[currentStage]["allEngines"], shipState["radiusVector"]:mag - body:radius)).
    set shipState["massFlow"] to stagesData[currentStage]["massFlow"].

    set predictedOrbit to CREATEORBIT(shipState["radiusVector"], shipState["velocityVector"], body, 0).
    until predictedOrbit:apoapsis >= targetAltitude or shipState["radiusVector"]:mag - body:radius < 0
    {
        CalculateNextStateInRotatingFrame(shipState, timeStep).
        if shipState["mass"] <= stagesData[currentStage]["endMass"]
        {
            set currentStage to currentStage - 1.
            set shipState["mass"] to stagesData[currentStage]["totalMass"].
            set shipState["massFlow"] to stagesData[currentStage]["massFlow"].
        }
        set shipState["thrustVector"] to -shipState["surfaceVelocityVector"]:normalized * GetEnginesThrust(stagesData[currentStage]["allEngines"], shipState["radiusVector"]:mag - body:radius).

        set predictedOrbit to CREATEORBIT(shipState["radiusVector"], shipState["velocityVector"], body, 0).
    }

    clearScreen.
    print "Altitude: " + Round(shipState["radiusVector"]:mag - body:radius, 2).
    print "Velocity: " + Round(shipState["surfaceVelocityVector"]:mag, 2).
    wait timeStep.
}

RunPath("circularize").

local function GetEnginesThrust
{
    local parameter engines is List().
    local parameter currentAltitude is 0.

    local totalThrust is 0.
    local atmosphericPressure is body:atm:AltitudePressure(currentAltitude).
    for engine in engines
    {
        set totalThrust to totalThrust + engine:PossibleThrustAt(atmosphericPressure).
    }

    return totalThrust.
}