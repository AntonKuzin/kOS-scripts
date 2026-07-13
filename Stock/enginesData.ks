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
        set data["maxMassFlow"] to data["maxMassFlow"] + engine:maxMassFlow * engine:thrustLimit / 100.
    }

    return data.
}

global function GetResiduals
{
    local parameter engines is ship:engines.

    return 0.
}

local accumulatedData is Lexicon(
        "thrust", 0,
        "massFlow", 0).
global function GetRunningAverage
{
    local parameter engines is ship:engines.
    
    set accumulatedData["thrust"] to 0.
    set accumulatedData["massFlow"] to 0.
    for engine in engines
    {
        set accumulatedData["thrust"] to accumulatedData["thrust"] + engine:thrust.
        set accumulatedData["massFlow"] to accumulatedData["massFlow"] + engine:massFlow.
    }

    return accumulatedData.
}