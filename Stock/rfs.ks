@lazyGlobal off.
clearVecDraws().

local parameter timeGuess is 3 * 60.

local targetRadiusVector is PositionAt(target, TimeStamp() + timeGuess) - body:position.

VecDraw(
    { return body:position. },
    { return targetRadiusVector. },
    MAGENTA,
    "Target",
    1,
    true).

  until ship:thrust > 1
  {
    set targetRadiusVector to PositionAt(target, TimeStamp() + timeGuess) - body:position.
    wait 1.
  }

  clearVecDraws().