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
