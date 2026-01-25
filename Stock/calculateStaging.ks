@lazyGlobal off.
RunOncePath("enginesData").

local stagesData is List().
local partToStageMap is Lexicon().
local partsQueue is Queue().

global function GetStagesData
{
    wait until stage:ready.
    
    set stagesData to List().
    set partToStageMap to Lexicon().
    partsQueue:push(Lexicon("stageIndex", 0, "part", ship:rootPart)).
    FROM {local i is 0.} UNTIL i > ship:stageNum STEP {set i to i + 1.} DO 
    {
        stagesData:Add(Lexicon(
            "totalVacuumThrust", 0,
            "totalSLThrust", 0,
            "massFlow", 0,
            "totalMass", 0,
            "fuelMass", 0,
            "endMass", 0,
            "activationIndex", i,
            "stageIndex", i,
            "feedsInto", -1,
            "drainsFrom", -1,
            "containsFairing", false,
            "parts", List(),
            "tanks", List(),
            "enginesDrainingFromTanksDroppedInCurrentStage", List(),
            "allActiveEngines", List())).
    }

    ProcessFairings().
    DisassembleRocketInDecouplingOrder().
    SetActivationIndexes().
    ProcessEngines().
    ProcessFuelCrossfeed().
    ProcessFuelTanks().
    //ProcessPayloadStages().
    SimulateFuelFlow().
    
    FROM {local i is 1.} UNTIL i > ship:stageNum STEP {set i to i + 1.} DO
    {
        set stagesData[i]["totalMass"] to stagesData[i]["totalMass"] + stagesData[i - 1]["totalMass"].
        set stagesData[i]["endMass"] to stagesData[i]["endMass"] + stagesData[i - 1]["totalMass"].
    }
    
    return stagesData.
}

local function ProcessFairings
{
    for part in ship:parts
    {
        if part:HasModule("ModuleProceduralFairing") and part:GetModule("ModuleProceduralFairing"):allEvents:Empty() = false
        {
            set stagesData[part:stage]["containsFairing"] to true.
        }
    }
}

local function DisassembleRocketInDecouplingOrder 
{
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
            HandleEnginePlate(currentPart, currentStageIndex).
        }
        else
        {
            HandleRegularPart(currentPart, currentStageIndex).
        }
    }
}

local function SetActivationIndexes
{
    for engine in ship:engines
    {
        set stagesData[partToStageMap[engine]]["activationIndex"] to Max(stagesData[partToStageMap[engine]]["activationIndex"], engine:stage).
    }
}

local function ProcessEngines
{
    for currentStage in stagesData
    {
        for currentPart in currentStage["parts"]
        {
            if currentPart:IsType("Engine") and currentPart:HasModule("ModuleDecouple") = false
            {
                if currentPart:stage >= currentStage["stageIndex"]
                {
                    currentStage["enginesDrainingFromTanksDroppedInCurrentStage"]:Add(currentPart).
                }
                
                FROM {local i is currentStage["stageIndex"].} UNTIL i > currentPart:stage STEP {set i to i + 1.} DO
                {
                    if currentPart:stage = stagesData[i]["activationIndex"]
                    {
                        stagesData[i]["allActiveEngines"]:Add(currentPart).
                    }
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
    local resourceIsCollected is false.
    local minResiduals is 0.
    for currentStage in stagesData
    {
        for currentPart in currentStage["parts"]
        {
            for resource in currentPart:resources
            {
                set resourceIsCollected to false.
                set minResiduals to GetResiduals(currentStage["enginesDrainingFromTanksDroppedInCurrentStage"]).
                for engine in currentStage["enginesDrainingFromTanksDroppedInCurrentStage"]
                {
                    for consumedResource in engine:consumedResources:keys
                    {
                        if engine:consumedResources[consumedResource]:name = resource:name
                        {
                            set resourceIsCollected to true.
                            if currentStage["tanks"]:Contains(currentPart) = false
                            {
                                currentStage["tanks"]:Add(currentPart).
                            }

                            if resource:enabled and currentStage["activationIndex"] >= currentStage["stageIndex"]
                            {
                                set currentStage["fuelMass"] to currentStage["fuelMass"] + resource:amount * resource:density.
                                set currentStage["fuelMass"] to currentStage["fuelMass"] - minResiduals * resource:capacity * resource:density.
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
            local stageFeedingTheCurrentOne is stagesData[currentStage["drainsFrom"]].
            for engine in currentStage["enginesDrainingFromTanksDroppedInCurrentStage"]
            {
                stageFeedingTheCurrentOne["enginesDrainingFromTanksDroppedInCurrentStage"]:Add(engine).
            }
        }
    }
}

local function SimulateFuelFlow
{
    FROM {local i is ship:stageNum.} UNTIL i < 0 STEP {set i to i - 1.} DO 
    {
        local burnTime is 0. 
        local fuelMassBurnedInUpperStage is 0.
        local massFlow is 0.
        local upperStageBurningFuelSimultaneously is 0.

        for engine in stagesData[i]["enginesDrainingFromTanksDroppedInCurrentStage"]
        {
            set massFlow to massFlow + engine:maxMassFlow * engine:thrustLimit / 100.
            set burnTime to stagesData[i]["fuelMass"] / massFlow. //prevents division by 0 if there's no engines
        }

        for engine in stagesData[i]["allActiveEngines"]
        {
            set stagesData[i]["totalVacuumThrust"] to stagesData[i]["totalVacuumThrust"] + engine:PossibleThrustAt(0).
            set stagesData[i]["totalSLThrust"] to stagesData[i]["totalSLThrust"] + engine:PossibleThrustAt(1).

            if stagesData[i]["enginesDrainingFromTanksDroppedInCurrentStage"]:Contains(engine) = false
            {
                set upperStageBurningFuelSimultaneously to partToStageMap[engine].
                set massFlow to massFlow + engine:maxMassFlow * engine:thrustLimit / 100.
                set fuelMassBurnedInUpperStage to burnTime * engine:maxMassFlow * engine:thrustLimit / 100.
                set stagesData[i]["fuelMass"] to stagesData[i]["fuelMass"] + fuelMassBurnedInUpperStage.
                set stagesData[i]["totalMass"] to stagesData[i]["totalMass"] + fuelMassBurnedInUpperStage.
                
                set stagesData[upperStageBurningFuelSimultaneously]["fuelMass"] to stagesData[upperStageBurningFuelSimultaneously]["fuelMass"] - fuelMassBurnedInUpperStage.
                set stagesData[upperStageBurningFuelSimultaneously]["totalMass"] to stagesData[upperStageBurningFuelSimultaneously]["totalMass"] - fuelMassBurnedInUpperStage.
            }
            set stagesData[i]["massFlow"] to massFlow.
        }
        
        set stagesData[i]["endMass"] to stagesData[i]["totalMass"] - stagesData[i]["fuelMass"].
    }
}

local function HandleEnginePlate
{
    parameter part.
    parameter currentStageIndex.

    for child in part:children
    {
        if child:isType("Engine")
        {
            partsQueue:Push(Lexicon("stageIndex", currentStageIndex, "part", child)).
        }
        else
        {
            local nextStageIndex is currentStageIndex + 1.
            until stagesData[nextStageIndex]["containsFairing"] = false and nextStageIndex < stagesData:length
            {
                set nextStageIndex to nextStageIndex + 1.
            }
            partsQueue:Push(Lexicon("stageIndex", nextStageIndex, "part", child)).
        }
    }
}

local function HandleRegularPart
{
    parameter part.
    parameter currentStageIndex.

    for child in part:children
    {
        if child:IsType("LaunchClamp")
            or child:HasModule("ProceduralFairingDecoupler")
            or ((child:HasModule("ModuleDecouple") or child:HasModule("ModuleAnchoredDecoupler"))
            and not child:HasModule("ModuleDynamicNodes"))
        {
            local nextStageIndex is child:stage + 1.
            until stagesData[nextStageIndex]["containsFairing"] = false and nextStageIndex < stagesData:length
            {
                set nextStageIndex to nextStageIndex + 1.
            }

            partsQueue:Push(Lexicon("stageIndex", nextStageIndex, "part", child)).
            
            if (child:HasModule("ModuleToggleCrossfeed") and child:GetModule("ModuleToggleCrossfeed"):HasEvent("disable crossfeed"))
            {
                set stagesData[nextStageIndex]["feedsInto"] to currentStageIndex.
                set stagesData[currentStageIndex]["drainsFrom"] to nextStageIndex.
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
        print "   Wet mass: " + Round(stagesData[i]["totalMass"], 3).
        print "   Dry mass: " + Round(stagesData[i]["endMass"], 3).
        print "   SL thrust: " + Round(stagesData[i]["totalSLThrust"], 3).
        print "   Vacuum thrust: " + Round(stagesData[i]["totalVacuumThrust"], 3).
    }
}