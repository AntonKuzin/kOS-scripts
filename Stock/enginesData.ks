@lazyGlobal off.

global function GetEnginesData
{
    local parameter engines is ship:engines.

    local data is Lexicon(
        "thrust", 0,
        "massFlow", 0,
        "isp", 0
    ).

    FOR engine in engines
    {
        if engine:ignition
        {
            set data["thrust"] to data["thrust"] + engine:possibleThrust.
            set data["massFlow"] to data["massFlow"] + engine:maxMassFlow * engine:thrustLimit / 100.
            set data["isp"] to data["thrust"] / data["massFlow"] / constant:g0.
        }
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
 
    for engine in engines
    {
        set accumulatedData["thrust"] to accumulatedData["thrust"] + engine:thrust.
        set accumulatedData["massFlow"] to accumulatedData["massFlow"] + engine:massFlow.
    }

    return accumulatedData.
}