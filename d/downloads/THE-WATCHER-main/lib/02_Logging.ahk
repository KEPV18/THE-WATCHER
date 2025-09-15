LogPerformance(operation, durationMs) {
    if (SETTINGS["EnablePerformanceLogging"]) {
        FileAppend(
            FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") 
            . "," . operation
            . "," . durationMs
            . "," . GdipResourceCount
            . "\n",
            A_ScriptDir . "\performance.log"
        )
    }
}