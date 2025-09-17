; ============================================================
; Watcher.ahk - Robust Guardian (AHK v2) - Final (fixed loop)
; Captures errors by reading last_error.log and exec.StdOut/StdErr
; ============================================================
#Requires AutoHotkey v2
#SingleInstance Force

; -------------- Config --------------
; قراءة الإعدادات العامة ومن ضمنها BOT_TOKEN/CHAT_ID عبر ملف الكور
#Include "lib\01_CoreSettings.ahk"

global SCRIPT_TO_RUN := A_ScriptDir "\master.ahk"
global SCRIPT_NAME   := "MasterDashboard"
global ERROR_LOG     := A_ScriptDir "\last_error.log"
global RESTART_DELAY := 3000

; -------------- Main Loop --------------
Loop {
    fullError := ""
    q := Chr(34)
    runCmd := q . A_AhkPath . q . " /ErrorStdOut " . q . SCRIPT_TO_RUN . q

    exitCode := RunAndCaptureAllErrors(runCmd, ERROR_LOG, &fullError)

    if (exitCode != 0 || (fullError && StrLen(Trim(fullError)) > 0)) {
        ReportCatastrophicFailure(exitCode, fullError)
        response := MsgBox(
            "The main script (" SCRIPT_NAME ") has crashed.`n"
            "A detailed failure report has been sent to Telegram.`n`n"
            "Do you want to try restarting it?",
            "Critical Failure", 36)

        if (response = "No") {
            ExitApp
        }
    }
    Sleep RESTART_DELAY
}

; -------------- Reporter --------------
ReportCatastrophicFailure(errorCode, errorText := "") {
    global BOT_TOKEN, CHAT_ID, SCRIPT_NAME

    err := Trim(errorText)
    if (!err)
        err := "[No error output captured]"

    ; ---------- extract File: and Line: safely using InStr/SubStr ----------
    filePath := ""
    lineNo := ""

    ; extract File:
    posFile := InStr(err, "File:", false, 1)
    if (posFile) {
        start := posFile + StrLen("File:")
        s := SubStr(err, start + 1) ; substring after "File:"
        nl := InStr(s, "`n", false, 1)
        if (nl)
            filePath := Trim(SubStr(s, 1, nl - 1))
        else
            filePath := Trim(s)
    }

    ; extract Line:
    posLine := InStr(err, "Line:", false, 1)
    if (posLine) {
        start := posLine + StrLen("Line:")
        s2 := SubStr(err, start + 1) ; substring after "Line:"
        ; gather digits from start of s2 using while (AHK v2 safe)
        digits := ""
        lenS2 := StrLen(s2)
        i := 1
        while (i <= lenS2) {
            ch := SubStr(s2, i, 1)
            if (ch >= "0" && ch <= "9")
                digits .= ch
            else
                break
            i += 1
        }
        if (digits)
            lineNo := digits
    }

    ; ---------- build message ----------
    header :=
        "🔥 CATASTROPHIC SCRIPT FAILURE 🔥`n" .
        "---------------------------------`n" .
        "Script: " . SCRIPT_NAME . "`n" .
        "Exit Code: " . errorCode . "`n"

    fileLineText := ""
    if (filePath)
        fileLineText .= "`n📂 File: " . filePath
    if (lineNo)
        fileLineText .= "`n📌 Line: " . lineNo

    errDisplay := err
    maxLen := 3500
    if (StrLen(errDisplay) > maxLen)
        errDisplay := SubStr(errDisplay, 1, maxLen) . "`n`n...[truncated]"

    ErrorMessage := header . fileLineText . "`n`n📜 Error Output:`n" . errDisplay . "`n`n" .
                    "Time: " . FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")

    ; إذا لم تكن مفاتيح تيليجرام مضبوطة، احفظ محليًا وتخطى الإرسال
    if (!BOT_TOKEN || !CHAT_ID) {
        try {
            FileAppend(FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . " - Telegram disabled (missing keys). Saved locally." . "`n", A_ScriptDir "\watcher_send_error.log", "UTF-8")
            FileAppend(ErrorMessage . "`n`n", A_ScriptDir "\watcher_send_error.log", "UTF-8")
        } catch {
        }
        return
    }

    ; Send with POST
    TelegramURL := "https://api.telegram.org/bot" . BOT_TOKEN . "/sendMessage"
    body := "chat_id=" . CHAT_ID . "&text=" . UriEncode(ErrorMessage)

    try {
        Req := ComObject("WinHttp.WinHttpRequest.5.1")
        Req.Open("POST", TelegramURL, false)
        Req.SetRequestHeader("Content-Type", "application/x-www-form-urlencoded")
        Req.Send(body)

        ; check HTTP status (best-effort)
        try {
            status := Req.Status
            resp := Req.ResponseText
            if (status && (status < 200 || status >= 300)) {
                FileAppend(FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . " - Telegram returned status " . status . "`nResp: " . SubStr(resp,1,1000) . "`n`n", A_ScriptDir "\watcher_send_error.log", "UTF-8")
            }
        } catch {
        }
    } catch {
        try {
            FileAppend(FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . " - Failed to send Telegram (exception)." . "`n", A_ScriptDir "\watcher_send_error.log", "UTF-8")
            FileAppend(ErrorMessage . "`n`n", A_ScriptDir "\watcher_send_error.log", "UTF-8")
        } catch {
        }
    }

    ; archive locally
    try {
        FileAppend("==== " . FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . " ====`n", A_ScriptDir "\last_error_archive.log", "UTF-8")
        FileAppend(ErrorMessage . "`n`n", A_ScriptDir "\last_error_archive.log", "UTF-8")
    } catch {
    }
}

; -------------- URL encode --------------
UriEncode(str, encoding := "UTF-8") {
    static hex := "0123456789ABCDEF"
    if (str = "")
        return ""
    bytes := StrPut(str, encoding) - 1
    buf := Buffer(bytes)
    StrPut(str, buf, encoding)
    out := ""
    Loop bytes {
        b := NumGet(buf, A_Index - 1, "UChar")
        if ((b >= 0x30 && b <= 0x39) || (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A) || b = 0x2D || b = 0x2E || b = 0x5F || b = 0x7E)
            out .= Chr(b)
        else if (b = 0x20)
            out .= "+"
        else
            out .= "%" . SubStr(hex, (b >> 4) + 1, 1) . SubStr(hex, (b & 0xF) + 1, 1)
    }
    return out
}

; -------------- Run & capture (improved) --------------
RunAndCaptureAllErrors(cmd, logFile, &errorOut := "") {
    ; delete old log
    try {
        FileDelete(logFile)
    } catch {
    }

    shell := ComObject("WScript.Shell")
    q := Chr(34)
    fullCmd := "cmd /c " . cmd . " > " . q . logFile . q . " 2>&1"

    ; write a start marker (helps debugging if log file is created)
    try {
        FileAppend("=== RUN START: " . FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . " ====`n", logFile, "UTF-8")
    } catch {
    }

    ; execute
    try {
        exec := shell.Exec(fullCmd)
    } catch {
        errorOut := "Failed to start process (Exec)."
        return 1
    }

    ; collect any immediate StdOut/StdErr (if available) while waiting
    collected := ""
    while (exec.Status = 0) {
        try {
            while !exec.StdOut.AtEndOfStream {
                collected .= exec.StdOut.ReadLine() . "`n"
            }
        } catch {
        }
        try {
            while !exec.StdErr.AtEndOfStream {
                collected .= exec.StdErr.ReadLine() . "`n"
            }
        } catch {
        }
        Sleep 50
    }

    ; drain remaining streams after exit
    try {
        while !exec.StdOut.AtEndOfStream {
            collected .= exec.StdOut.ReadLine() . "`n"
        }
    } catch {
    }
    try {
        while !exec.StdErr.AtEndOfStream {
            collected .= exec.StdErr.ReadLine() . "`n"
        }
    } catch {
    }

    ; read the log file if exists
    fileText := ""
    if (FileExist(logFile)) {
        try {
            fileText := FileRead(logFile, "UTF-8")
        } catch {
            fileText := ""
        }
    }

    ; choose the best available output
    if (fileText && StrLen(Trim(fileText)) > 0)
        errorOut := fileText
    else if (collected && StrLen(Trim(collected)) > 0)
        errorOut := collected
    else
        errorOut := ""

    return exec.ExitCode
}
