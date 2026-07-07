@lazyGlobal off.

global function GetEnginesData
{
    local parameter engines is ship:engines.

    local data is Lexicon(
        "slThrust", 0,
        "vacuumThrust", 0,
        "massFlow", 0
    ).

    FOR engine in engines
    {
        set data["slThrust"] to data["slThrust"] + engine:possibleThrustAt(1).
        set data["vacuumThrust"] to data["vacuumThrust"] + engine:possibleThrustAt(0).

        local minThrottle is engine:GetModule("ModuleEnginesRF"):GetHiddenField("min throttle").
        set data["massFlow"] to data["massFlow"] + engine:maxMassFlow * (minThrottle + engine:thrustLimit / 100 * (1 - minThrottle)).
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

    if currentStage <> ship:stageNum or Abs(ship:thrust - accumulatedData["thrust"]) / ship:thrust > 0.1
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