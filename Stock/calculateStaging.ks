@lazyGlobal off.
RunOncePath("algorithm").

local stagesData is List().
local partToStageMap is Lexicon().

global function GetStagesData
{
    set stagesData to List().
    set partToStageMap to Lexicon().
    FROM {local i is ship:stageNum.} UNTIL i < 0 STEP {set i to i - 1.} DO 
    {
        stagesData:Add(Lexicon(
            "totalVacuumThrust", 0,
            "totalSLThrust", 0,
            "massFlow", 0,
            "totalMass", 0,
            "fuelMass", 0,
            "endMass", 0,
            "activationIndex", 0,
            "stageIndex", 0,
            "parts", List(),
            "tanks", List(),
            "engines", List(),
            "allEngines", List())).
    }

    DisassembleRocketInDecouplingOrder().
    ProcessEngines().
    ProcessFuelTanks().
    SimulateFuelFlow().
    FROM {local i is 1.} UNTIL i > ship:stageNum STEP {set i to i + 1.} DO
    {
        set stagesData[i]["totalMass"] to stagesData[i]["totalMass"] + stagesData[i - 1]["totalMass"].
        set stagesData[i]["endMass"] to stagesData[i]["endMass"] + stagesData[i - 1]["totalMass"].
    }
    
    // BubbleSort(stagesData, 
    //     {
    //         parameter left, right.
    //         return choose left["stageIndex"] > right["stageIndex"]
    //                if left["activationIndex"] = right["activationIndex"]
    //                else left["activationIndex"] > right["activationIndex"].
    //     }).

    
    return stagesData.
}

local function DisassembleRocketInDecouplingOrder 
{
    local partsQueue is Queue(Lexicon("stageIndex", 0, "part", ship:rootPart)).
    until partsQueue:empty
    {
        local currentNode is partsQueue:Pop().
        local currentStageIndex is currentNode["stageIndex"].
        local currentPart is currentNode["part"].

        set stagesData[currentStageIndex]["totalMass"] to stagesData[currentStageIndex]["totalMass"] + currentPart:mass.
        set stagesData[currentStageIndex]["stageIndex"] to currentStageIndex.

        stagesData[currentStageIndex]["parts"]:Add(currentPart).
        partToStageMap:Add(currentPart, currentStageIndex).
        if currentPart:IsType("Decoupler") and currentPart:HasModule("ModuleDynamicNodes")
        {
            HandleEnginePlate(currentPart, partsQueue, currentStageIndex).
        }
        else
        {
            HandleRegularPart(currentPart, partsQueue, currentStageIndex).
        }
    }
}

local function ProcessEngines
{
    for currentStage in stagesData
    {
        for currentPart in currentStage["parts"]
        {
            if currentPart:IsType("Engine")
            {
                set currentStage["activationIndex"] to max(currentStage["activationIndex"], currentPart:stage).
                currentStage["engines"]:Add(currentPart).
                FROM {local i is currentStage["stageIndex"].} UNTIL i > currentPart:stage STEP {set i to i + 1.} DO
                {
                    stagesData[i]["allEngines"]:Add(currentPart).
                }
            }
        }
    }
}

local function ProcessFuelTanks
{
    for currentStage in stagesData
    {
        for currentPart in currentStage["parts"]
        {
            for resource in currentPart:resources
            {
                for engine in currentStage["engines"]
                {
                    if engine:consumedResources:keys:Contains(resource:name)
                    {
                        if currentStage["tanks"]:Contains(currentPart) = False
                        {
                            currentStage["tanks"]:Add(currentPart).
                            for fuel in currentPart:resources
                            {
                                if fuel:enabled
                                {
                                    set currentStage["fuelMass"] to currentStage["fuelMass"] + fuel:amount * fuel:density.
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

local function SimulateFuelFlow
{
    FROM {local i is ship:stageNum.} UNTIL i < 0 STEP {set i to i - 1.} DO 
    {
        local burnTime is 0. 
        local burnedMass is 0.
        local massFlow is 0.
        local stageToDrainFrom is 0.

        for engine in stagesData[i]["engines"]
        {
            set massFlow to massFlow + engine:maxMassFlow * engine:thrustLimit / 100.
            set burnTime to stagesData[i]["fuelMass"] / massFlow.
        }

        for engine in stagesData[i]["allEngines"]
        {
            set stageToDrainFrom to partToStageMap[engine].
            set stagesData[i]["totalVacuumThrust"] to stagesData[i]["totalVacuumThrust"] + engine:PossibleThrustAt(0).
            set stagesData[i]["totalSLThrust"] to stagesData[i]["totalSLThrust"] + engine:PossibleThrustAt(1).

            if stagesData[i]["engines"]:Contains(engine) = False
            {
                set massFlow to massFlow + engine:maxMassFlow * engine:thrustLimit / 100.
                set burnedMass to burnTime * engine:maxMassFlow * engine:thrustLimit / 100.
                set stagesData[i]["fuelMass"] to stagesData[i]["fuelMass"] + burnedMass.
                set stagesData[i]["totalMass"] to stagesData[i]["totalMass"] + burnedMass.

                
                set stagesData[stageToDrainFrom]["fuelMass"] to stagesData[stageToDrainFrom]["fuelMass"] - burnedMass.
                set stagesData[stageToDrainFrom]["totalMass"] to stagesData[stageToDrainFrom]["totalMass"] - burnedMass.
            }
            set stagesData[i]["massFlow"] to massFlow.
        }
        
        set stagesData[i]["endMass"] to stagesData[i]["totalMass"] - stagesData[i]["fuelMass"].
    }
}

local function HandleEnginePlate
{
    parameter part.
    parameter partsQueue.
    parameter currentStageIndex.

    for child in part:children
    {
        if child:isType("Engine")
        {
            partsQueue:Push(Lexicon("stageIndex", currentStageIndex, "part", child)).
        }
        else
        {
            partsQueue:Push(Lexicon("stageIndex", currentStageIndex + 1, "part", child)).
        }
    }
}

local function HandleRegularPart
{
    parameter part.
    parameter partsQueue.
    parameter currentStageIndex.

    for child in part:children
    {
        if child:IsType("Decoupler") and not child:HasModule("ModuleDynamicNodes")
        {
            partsQueue:Push(Lexicon("stageIndex", child:stage + 1, "part", child)).
            set stagesData[child:stage + 1]["activationIndex"] to child:stage + 1.
            
            // if (child:HasModule("ModuleToggleCrossfeed") and child:GetModule("ModuleToggleCrossfeed"):HasEvent("disable crossfeed"))
            // {
            //     set stagesData[child:stage + 1]["feedsInto"] to currentStageIndex.
            //     stagesData[currentStageIndex]["drainsFrom"]:Add(child:stage + 1).
            // }
        }
        else
        {
            partsQueue:Push(Lexicon("stageIndex", currentStageIndex, "part", child)).
        }
    }
}

local function PrintData
{
    from {local i is 0.} until i = stagesData:length step {set i to i + 1.} do
    {
        print "Stage №: " + i.
        print "   Wet mass: " + stagesData[i]["totalMass"].
        print "   Dry mass: " + stagesData[i]["endMass"].
        print "   SL thrust: " + stagesData[i]["totalSLThrust"].
        print "   Vacuum thrust: " + stagesData[i]["totalVacuumThrust"].
    }
}