@lazyGlobal off.
RunOncePath("calculateStaging").
RunOncePath("motionPrediction").
RunOncePath("drag").
clearVecDraws().

local parameter LAN is -1.
local parameter inclination is orbit:inclination.
local parameter targetAltitude is 75000.

if LAN <> -1
{
    local launchTimeOffset is 60.
    local targetAngularDifference is ArcSin(tan(orbit:inclination) / tan(inclination)).
    local launchSiteInNorthernHemisphere is 
        choose 1
        if VectorAngle(-body:position, Sun:Up:topVector) < 90
        else -1.
    local launchOnAscendingPass is 1.
    local headingOffset is 90 - ArcSin(Cos(inclination) / Cos(orbit:inclination)).

    local targetNodeVector is AngleAxis(LAN + launchSiteInNorthernHemisphere * launchOnAscendingPass * targetAngularDifference, -Sun:Up:topVector) * solarPrimeVector.
    local equatorialPlaneVector is vectorExclude(-Sun:Up:topVector, ship:position - body:position).
    local currentAngularDifference is VectorAngle(targetNodeVector, equatorialPlaneVector).
    local timeToWait is currentAngularDifference / (body:angularvel:mag * constant:radtodeg).
    local previousTimeToWait is timeToWait.

    until timeToWait <= launchTimeOffset
    {
        set targetNodeVector to AngleAxis(LAN + launchSiteInNorthernHemisphere * launchOnAscendingPass * targetAngularDifference, -Sun:Up:topVector) * solarPrimeVector.
        set equatorialPlaneVector to vectorExclude(-Sun:Up:topVector, ship:position - body:position).
        set currentAngularDifference to VectorAngle(targetNodeVector, equatorialPlaneVector).
        set timeToWait to currentAngularDifference / (body:angularvel:mag * constant:radtodeg).

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

local timeStep is 2.
local integrationSteps is 0.

local stagesData is GetStagesData().
local shipState is CreateShipState().
local stateChangeSources is CreateStateChangeSources().
set stateChangeSources["externalForcesDelegate"] to { local parameter state. return GetAeroForcesVector(state["altitude"], state["surfaceVelocityVector"]). }.
set stateChangeSources["thrustDelegate"] to { local parameter state. return -state["surfaceVelocityVector"]:normalized * GetEnginesThrust(stagesData[currentStage]["allEngines"], shipState["altitude"]). }.

local predictedOrbit is CREATEORBIT(-body:position, velocity:orbit, body, 0).

local currentStage is ship:stageNum.
until orbit:apoapsis >= targetAltitude
{
    set integrationSteps to 0.

    if currentStage > ship:stageNum
    {
        set currentStage to ship:stageNum.
        wait until stage:ready.
        set stagesData to GetStagesData().
    }
    set currentStage to ship:stageNum.

    UpdateShipState(shipState).
    set stateChangeSources["massFlow"] to stagesData[currentStage]["massFlow"].

    set predictedOrbit to CREATEORBIT(shipState["radiusVector"], shipState["velocityVector"], body, 0).
    until ship:velocity:surface:mag < 1 or predictedOrbit:apoapsis >= targetAltitude or shipState["altitude"] < 0
    {
        CalculateNextStateInRotatingFrame(shipState, stateChangeSources, timeStep).
        if shipState["mass"] <= stagesData[currentStage]["endMass"] and currentStage > 0
        {
            set currentStage to currentStage - 1.
            set shipState["mass"] to stagesData[currentStage]["totalMass"].
            set stateChangeSources["massFlow"] to stagesData[currentStage]["massFlow"].
        }

        set predictedOrbit to CREATEORBIT(shipState["radiusVector"], shipState["velocityVector"], body, 0).
        set integrationSteps to integrationSteps + 1.
    }

    if integrationSteps < 50
    {
        set timeStep to Max(0.05, timeStep / 2).
    }

    clearScreen.
    print "Altitude: " + Round(shipState["altitude"], 2).
    print "Velocity: " + Round(shipState["surfaceVelocityVector"]:mag, 2).
    wait 0.
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

local function GetAeroForcesVector
{
    local parameter currentAltitude is 0, velocityVector is V(0, 0, 0).
    
    local aeroForcesVector is addons:far:AeroForceAt(currentAltitude, ship:facing:foreVector * velocityVector:mag).
    set aeroForcesVector to RotateFromTo(ship:facing:foreVector, velocityVector) * aeroForcesVector.
    
    return aeroForcesVector.
}