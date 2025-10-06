@lazyGlobal off.

global function BubbleSort
{
    parameter array.
    parameter comparator.

    local isSorted is false.
    local temp is 0.
    FROM {local i is 0.} UNTIL (i = array:length - 1 or isSorted = true) STEP {set i to i + 1.} DO
    {
        set isSorted to true.
        FROM {local j is 0.} UNTIL (j = array:length - 1 - i) STEP {set j to j + 1.} DO
        {
            if (comparator(array[j], array[j + 1]))
            {
                set temp to array[j].
                set array[j] to array[j + 1].
                set array[j + 1] to temp.
                set isSorted to false.
            }
        }
    }
}