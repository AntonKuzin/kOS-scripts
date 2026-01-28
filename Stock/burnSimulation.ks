@lazyGlobal off.
RunOncePath("motionPrediction").

global function CreateBurnIntegrator
{
    local parameter shipState, stateChangeSources, stagesData, timeStep, burnEndCriterion, timeStepLimiter is { return timeStep.}.

    local integrator is Lexicon(
        "run", SimulateBurn@,
        "currentStage", ship:stageNum,
        "timeRequired", 0,
        "deltaVRequired", 0
    ).

    local clampedTimeStep is timeStep.
    local function SimulateBurn
    {
        set integrator["timeRequired"] to 0.
        set integrator["deltaVRequired"] to 0.

        set integrator["currentStage"] to ship:stageNum.
        until burnEndCriterion()
        {
            until shipState["mass"] > stagesData[integrator["currentStage"]]["endMass"] or integrator["currentStage"] = 0
            {
                set integrator["currentStage"] to integrator["currentStage"] - 1.
                set shipState["mass"] to stagesData[integrator["currentStage"]]["totalMass"].
                set stateChangeSources["massFlow"] to stagesData[integrator["currentStage"]]["massFlow"].
            }

            set clampedTimeStep to Min(timeStep, timeStepLimiter()).
            set clampedTimeStep to Min(clampedTimeStep, Max((shipState["mass"] - stagesData[integrator["currentStage"]]["endMass"]), 0.001) / stateChangeSources["massFlow"]).
            if ship:altitude < 100000
                CalculateNextStateInRotatingFrame(shipState, stateChangeSources, clampedTimeStep).
            else
                CalculateNextStateInInertialFrame(shipState, stateChangeSources, clampedTimeStep).

            set integrator["timeRequired"] to integrator["timeRequired"] + clampedTimeStep.
            set integrator["deltaVRequired"] to integrator["deltaVRequired"] + shipState["engineAcceleration"]:mag * clampedTimeStep.
        }
        set timeStep to Max(integrator["timeRequired"] / 60, 0.1).
    }

    return integrator.
}
