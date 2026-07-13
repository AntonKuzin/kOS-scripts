@lazyGlobal off.

global function GetEnginesData
{
    local parameter engines is ship:engines.

    local data is Lexicon(
        "maxSlThrust", 0,
        "maxVacuumThrust", 0,
        "maxMassFlow", 0,
        "minSlThrust", 0,
        "minVacuumThrust", 0,
        "minMassFlow", 0
    ).

    FOR engine in engines
    {
        set data["maxSlThrust"] to data["maxSlThrust"] + engine:possibleThrustAt(1).
        set data["maxVacuumThrust"] to data["maxVacuumThrust"] + engine:possibleThrustAt(0).

        local minThrottle is engine:GetModule("ModuleEnginesRF"):GetHiddenField("min throttle").
        set data["maxMassFlow"] to data["maxMassFlow"] + engine:maxMassFlow * (minThrottle + engine:thrustLimit / 100 * (1 - minThrottle)).
        set data["minSlThrust"] to data["minSlThrust"] + engine:possibleThrustAt(1) * minThrottle.
        set data["minVacuumThrust"] to data["minVacuumThrust"] + engine:possibleThrustAt(0) * minThrottle.
        set data["minMassFlow"] to data["minMassFlow"] + engine:maxMassFlow * minThrottle.
    }

    return data.
}

global function GetResiduals
{
    local parameter engines is ship:engines.

    local minResiduals is 1.
    for engine in engines
    {
        set minResiduals to Min(minResiduals, engine:GetModule("ModuleEnginesRF"):GetHiddenField("calculatedResiduals")).
    }

    return minResiduals.
}

local accumulatedData is Lexicon(
        "accumulatedThrust", 0,
        "accumulatedMassFlow", 0,
        "thrust", 0,
        "massFlow", 0).
local iterations is 0.
local currentStage is -1.
global function GetRunningAverage
{
    local parameter engines is ship:engines.

    if currentStage <> ship:stageNum or Abs(ship:thrust - accumulatedData["thrust"]) / ship:thrust > 0.01
    {
        set currentStage to ship:stageNum.
        ResetRunningAverage().
    }
    
    set iterations to iterations + 1.
    for engine in engines
    {
        set accumulatedData["accumulatedThrust"] to accumulatedData["accumulatedThrust"] + engine:thrust.
        set accumulatedData["accumulatedMassFlow"] to accumulatedData["accumulatedMassFlow"] + engine:massFlow.
    }
    set accumulatedData["thrust"] to accumulatedData["accumulatedThrust"] / iterations.
    set accumulatedData["massFlow"] to accumulatedData["accumulatedMassFlow"] / iterations.

    return accumulatedData.
}

local function ResetRunningAverage
{
    set accumulatedData["accumulatedThrust"] to 0.
    set accumulatedData["accumulatedMassFlow"] to 0.
    set accumulatedData["thrust"] to 0.
    set accumulatedData["massFlow"] to 0.
    set iterations to 0.
}