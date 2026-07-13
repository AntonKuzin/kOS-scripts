@lazyGlobal off.
RunOncePath("motionPrediction").

global function CreateBurnIntegrator
{
    local parameter shipState, stateChangeSources, stagesData, timeStep, burnEndCriterion, timeStepLimiter is { return timeStep. }, integrationSteps is 30.

    local integrator is Lexicon(
        "run", SimulateBurn@,
        "currentStage", ship:stageNum,
        "timeRequired", 0,
        "deltaVRequired", 0,
        "timeStep", timeStep
    ).

    local clampedTimeStep is integrator["timeStep"].
    local iterations is 0.
    local function SimulateBurn
    {
        set integrator["timeRequired"] to 0.
        set integrator["deltaVRequired"] to 0.
        set iterations to 0.

        set integrator["currentStage"] to ship:stageNum.
        until burnEndCriterion() or iterations > integrationSteps * 2
        {
            until shipState["mass"] > stagesData[integrator["currentStage"]]["endMass"] or integrator["currentStage"] = 0
            {
                set integrator["currentStage"] to integrator["currentStage"] - 1.
                set shipState["mass"] to stagesData[integrator["currentStage"]]["totalMass"].
                set stateChangeSources["massFlow"] to stagesData[integrator["currentStage"]]["maxMassFlow"].
            }

            set clampedTimeStep to Min(integrator["timeStep"], timeStepLimiter()).
            set clampedTimeStep to Min(clampedTimeStep, Max((shipState["mass"] - stagesData[integrator["currentStage"]]["endMass"]), 0.001) / stateChangeSources["massFlow"]).
            if ship:altitude < 100000
                CalculateNextStateInRotatingFrame(shipState, stateChangeSources, clampedTimeStep).
            else
                CalculateNextStateInInertialFrame(shipState, stateChangeSources, clampedTimeStep).

            set integrator["timeRequired"] to integrator["timeRequired"] + clampedTimeStep.
            set integrator["deltaVRequired"] to integrator["deltaVRequired"] + shipState["engineAccelerationVector"]:mag * clampedTimeStep.

            set iterations to iterations + 1.
        }
        set integrator["timeStep"] to Max(integrator["timeRequired"] / integrationSteps, 0.1).
    }

    return integrator.
}
