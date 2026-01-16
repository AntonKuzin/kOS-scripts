@lazyGlobal off.

global function GetEnginesData
{
    local parameter engines is ship:engines.

    local thrust is 0.
    local maxMassFlow is 0.
    FOR engine in engines
    {
        if engine:ignition
        {
            set thrust to thrust + engine:possibleThrust.
            set maxMassFlow to maxMassFlow + engine:maxMassFlow * engine:thrustLimit / 100.
        }
    }

    return Lexicon(
        "thrust", thrust,
        "massFlow", maxMassFlow,
        "isp", thrust / maxMassFlow / constant:g0
    ).
}
