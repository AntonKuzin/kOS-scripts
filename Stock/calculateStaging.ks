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
            "feedsInto", -1,
            "drainsFrom", -1,
            "parts", List(),
            "tanks", List(),
            "engines", List(),
            "allEngines", List())).
    }

    DisassembleRocketInDecouplingOrder().
    ProcessEngines().
    ProcessFuelCrossfeed().
    ProcessFuelTanks().
    ProcessPayloadStages().
    SimulateFuelFlow().
    
    FROM {local i is 1.} UNTIL i > ship:stageNum STEP {set i to i + 1.} DO
    {
        set stagesData[i]["totalMass"] to stagesData[i]["totalMass"] + stagesData[i - 1]["totalMass"].
        set stagesData[i]["endMass"] to stagesData[i]["endMass"] + stagesData[i - 1]["totalMass"].
    }
    
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
                set currentStage["activationIndex"] to currentPart:stage.
                if currentPart:stage >= currentStage["stageIndex"]
                {
                    currentStage["engines"]:Add(currentPart).
                }
                
                FROM {local i is currentStage["stageIndex"].} UNTIL i > currentPart:stage STEP {set i to i + 1.} DO
                {
                    stagesData[i]["allEngines"]:Add(currentPart).
                }
            }
        }
    }
}

local function ProcessPayloadStages
{
    for currentStage in stagesData
    {
        local payloadCarrierStage is stagesData[currentStage["activationIndex"]].
        if currentStage["activationIndex"] > currentStage["stageIndex"] and payloadCarrierStage["tanks"]:Empty()
        {
            for tank in currentStage["tanks"]
            {
                payloadCarrierStage["tanks"]:Add(tank).
            }
            set payloadCarrierStage["totalMass"] to payloadCarrierStage["totalMass"] + currentStage["fuelMass"].
            set payloadCarrierStage["fuelMass"] to payloadCarrierStage["fuelMass"] + currentStage["fuelMass"].
            set currentStage["totalMass"] to currentStage["totalMass"] - currentStage["fuelMass"].
            set currentStage["fuelMass"] to 0.
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
                local resourceIsCollected is false.
                for engine in currentStage["engines"]
                {
                    for key in engine:consumedResources:keys
                    {
                        if engine:consumedResources[key]:name = resource:name
                        {
                            set resourceIsCollected to true.
                            if currentStage["tanks"]:Contains(currentPart) = false
                            {
                                currentStage["tanks"]:Add(currentPart).
                            }

                            if resource:enabled and currentStage["activationIndex"] >= currentStage["stageIndex"]
                            {
                                set currentStage["fuelMass"] to currentStage["fuelMass"] + resource:amount * resource:density.
                            }
                        }
                    }

                    if resourceIsCollected
                    {
                        break.
                    }
                }
            }
        }
    }
}

local function ProcessFuelCrossfeed
{
    FROM {local i is ship:stageNum.} UNTIL i < 0 STEP {set i to i - 1.} DO 
    {
        if stagesData[i]["feedsInto"] <> -1
        {
            FROM {local j is i - 1.} UNTIL j < 0 STEP {set j to j - 1.} DO 
            {
                if stagesData[i]["feedsInto"] = stagesData[j]["feedsInto"]
                {
                    set stagesData[i]["feedsInto"] to j.
                    set stagesData[j]["drainsFrom"] to i.
                    break.
                }
            }
        }
    }

    for currentStage in stagesData
    {
        if currentStage["drainsFrom"] <> -1
        {
            for engine in currentStage["engines"]
            {
                stagesData[currentStage["drainsFrom"]]["engines"]:Add(engine).
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

            if stagesData[i]["engines"]:Contains(engine) = false
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
            
            if (child:HasModule("ModuleToggleCrossfeed") and child:GetModule("ModuleToggleCrossfeed"):HasEvent("disable crossfeed"))
            {
                set stagesData[child:stage + 1]["feedsInto"] to currentStageIndex.
                set stagesData[currentStageIndex]["drainsFrom"] to child:stage + 1.
            }
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