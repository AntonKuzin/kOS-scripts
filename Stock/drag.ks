@lazyGlobal off.
RunOncePath("motionPrediction").

local subSteps is 5.

global function GetCurrentDragCoefficient
{
    local parameter shipState is Lexicon().

    local previousTime is TimeStamp().
    wait 0.
    local currentTime is TimeStamp().
    local timeStep is (currentTime - previousTime):seconds / substeps.

    FROM {local i is substeps.} UNTIL i = 0 STEP {set i to i-1.} DO
    {
        CalculateNextStateInRotatingFrame(shipState, timeStep).
    }

    local drag is (ship:velocity:surface - shipState["surfaceVelocityVector"]):mag / (timeStep * subSteps).
    local dragCoefficient is (drag * ship:mass) / (ship:q * constant:atmTokPa).

    return dragCoefficient.
}