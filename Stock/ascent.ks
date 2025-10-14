@lazyGlobal off.
RunOncePath("calculateStaging").
RunOncePath("motionPrediction").

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