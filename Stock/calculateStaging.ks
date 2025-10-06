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
            "stagingIndex", 0,
            "parts", List(),
            "tanks", Lexicon(),
            "engines", Lexicon())).
    }

    DisassembleRocketInDecouplingOrder().
    FROM {local i is 1.} UNTIL i > ship:stageNum STEP {set i to i + 1.} DO
    {
        set stagesData[i]["totalMass"] to stagesData[i]["totalMass"] + stagesData[i - 1]["totalMass"].
    }
    ProcessEngines().
    ProcessFuelTanks().
    SimulateFuelFlow().
    

    // BubbleSort(stagesData, 
    //     {
    //         parameter left, right.
    //         return choose left["stagingIndex"] > right["stagingIndex"]
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
        set stagesData[currentStageIndex]["stagingIndex"] to currentStageIndex.

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
                currentStage["engines"]:Add(currentPart, List()).
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
                for engine in currentStage["engines"]:keys
                {
                    if engine:consumedResources:keys:Contains(resource:name)
                    {
                        if currentStage["tanks"]:HasKey(currentPart) = False
                        {
                            currentStage["tanks"]:Add(currentPart, List()).
                            for fuel in currentPart:resources
                            {
                                if fuel:enabled
                                {
                                    set currentStage["fuelMass"] to currentStage["fuelMass"] + fuel:amount * fuel:density.
                                }
                            }
                        }

                        if currentStage["tanks"][currentPart]:Contains(engine) = False
                        {
                            currentStage["tanks"][currentPart]:Add(engine).
                        }

                        if currentStage["engines"][engine]:Contains(currentPart) = False
                        {
                            FROM {local i is currentStage["stagingIndex"].} UNTIL i > engine:stage STEP {set i to i + 1.} DO
                            {
                                if stagesData[i]["engines"]:HasKey(engine) = False
                                {
                                    stagesData[i]["engines"]:Add(engine, List()).
                                }
                                stagesData[i]["engines"][engine]:Add(currentPart).
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
        local processedEngines is List().

        for tank in stagesData[i]["tanks"]:keys
        {
            for engine in stagesData[i]["tanks"][tank]
            {
                set massFlow to massFlow + engine:maxMassFlow * engine:thrustLimit / 100.
                processedEngines:Add(engine).
            }
            set burnTime to stagesData[i]["fuelMass"] / massFlow.
        }

        for engine in stagesData[i]["engines"]:keys
        {
            set stagesData[i]["totalVacuumThrust"] to stagesData[i]["totalVacuumThrust"] + engine:PossibleThrustAt(0).
            set stagesData[i]["totalSLThrust"] to stagesData[i]["totalSLThrust"] + engine:PossibleThrustAt(1).

            if processedEngines:Contains(engine) = False
            {
                set massFlow to massFlow + engine:maxMassFlow * engine:thrustLimit / 100.

                set burnedMass to burnTime * engine:maxMassFlow * engine:thrustLimit / 100.
                set stagesData[i]["fuelMass"] to stagesData[i]["fuelMass"] + burnedMass.
                for tank in stagesData[i]["engines"][engine]
                {
                    set stagesData[partToStageMap[tank]]["fuelMass"] to stagesData[partToStageMap[tank]]["fuelMass"] - burnedMass.
                    set stagesData[partToStageMap[tank]]["totalMass"] to stagesData[partToStageMap[tank]]["totalMass"] - burnedMass.
                }
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
            
            if (child:HasModule("ModuleToggleCrossfeed") and child:GetModule("ModuleToggleCrossfeed"):HasEvent("disable crossfeed"))
            {
                set stagesData[child:stage + 1]["feedsInto"] to currentStageIndex.
                stagesData[currentStageIndex]["drainsFrom"]:Add(child:stage + 1).
            }
        }
        else
        {
            partsQueue:Push(Lexicon("stageIndex", currentStageIndex, "part", child)).
        }
    }
}