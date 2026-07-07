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
        set data["massFlow"] to data["massFlow"] + engine:maxMassFlow * engine:thrustLimit / 100.
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