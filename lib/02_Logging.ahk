; ============================================================
; 02_Logging.ahk - Logging Module
; ============================================================

; --- Logging Configuration ---
global logFile := A_ScriptDir "\master_log.txt"
global LOG_MAX_BYTES := 1024 * 1024 * 3 ; 3 MB
global LogLevel := Map("DEBUG", 1, "INFO", 2, "WARN", 3, "ERROR", 4, "CRITICAL", 5)
global defaultLogLevel := "DEBUG"

; --- Core Logging Function ---
Log(level, msg) {
    global logFile, LOG_MAX_BYTES, defaultLogLevel, LogLevel
    if !LogLevel.Has(level)
        level := defaultLogLevel
    timestamp := A_Now
    entry := "[" . timestamp . "] [" . level . "] " . msg . "`n"
    try {
        FileAppend(entry, logFile, "UTF-8")
        if FileExist(logFile) {
            if (FileGetSize(logFile) > LOG_MAX_BYTES) {
                backup := logFile . ".1"
                if FileExist(backup)
                    FileDelete(backup)
                FileMove(logFile, backup)
                FileAppend("[" . A_Now . "] [INFO] Log rotated.`n", logFile, "UTF-8")
            }
        }
    } catch as ex {
        ToolTip("Log error: " . ex.Message, 10, 10)
        SetTimer(() => ToolTip(), -3000)
    }
}

; --- Logging Shortcuts ---
Info(msg) => Log("INFO", msg)
Debug(msg) => Log("DEBUG", msg)
Warn(msg) => Log("WARN", msg)
LogError(msg) => Log("ERROR", msg)
LogCritical(msg) => Log("CRITICAL", msg)
