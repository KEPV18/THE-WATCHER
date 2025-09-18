#Requires AutoHotkey v2.0
#SingleInstance Force

; ActivityProbe.ahk - standalone tester for detecting mouse vs keyboard activity
;
; How it works:
; - Polls A_TimeIdlePhysical and mouse position every 100ms
; - If mouse position changes -> counts as mouse activity
; - If idle resets without mouse move -> counts as keyboard activity
;
; Hotkeys:
;   Esc  -> Exit
;   F5   -> Restart the test flow

global lastMouseX := 0
global lastMouseY := 0
global lastIdlePhysical := A_TimeIdlePhysical
global lastActivity := "none"

; Test state
global step := 0                 ; 0=idle, 1=mouse test, 2=keyboard test, 3=done
global successMouse := false
global successKeyboard := false

; Idle gating before asking for action
global idleStableForMs := 0
IdleGateMs := 3000               ; require 3s of true idle before attempting detection
global moveThreshold := 2        ; pixels to consider as a real mouse move
global logFile := A_ScriptDir "\ActivityProbe.log"

Log(msg) {
    global logFile
    ts := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    FileAppend(ts " - " msg "`n", logFile, "UTF-8")
}

; UI setup
ui := Gui("+AlwaysOnTop", "Activity Probe")
ui.SetFont("s10", "Segoe UI")
ui.AddText("", "Instructions:")
LblInstr := ui.AddText("w420", "Click 'Start Test' to begin.")
ui.AddText("", "Live Status:")
LblIdle := ui.AddText("w420", "IdlePhysical: ... ms")
LblMouse := ui.AddText("w420", "Mouse: x=.. y=..  (Δ=..)")
LblLast := ui.AddText("w420", "LastActivity: none")
ui.AddText("", "Results:")
ResMouse := ui.AddText("w420 cGray", "Mouse detection: pending")
ResKey := ui.AddText("w420 cGray", "Keyboard detection: pending")

Row := ui.Add("Text")
BtnStart := ui.AddButton("w140 Default", "Start Test")
BtnStart.OnEvent("Click", StartTest)
BtnReset := ui.AddButton("x+10 w120", "Reset (F5)")
BtnReset.OnEvent("Click", (*) => ResetTest())
BtnStop := ui.AddButton("x+10 w100", "Stop")
BtnStop.OnEvent("Click", (*) => StopTest())
BtnExit := ui.AddButton("x+10 w100", "Exit (Esc)")
BtnExit.OnEvent("Click", (*) => ExitApp())
ui.Show("AutoSize")

; Hotkeys (v2 style)
Hotkey "Esc", (*) => ExitApp()
Hotkey "F5", (*) => ResetTest()
Hotkey "F6", (*) => StopTest()

; Initialize last mouse position to avoid false first movement
MouseGetPos &lastMouseX, &lastMouseY

; Start polling timer
SetTimer(ProbeTimer, 100)
return

StartTest(*) {
    global step, successMouse, successKeyboard, idleStableForMs
    global LblInstr, ResMouse, ResKey
    successMouse := false
    successKeyboard := false
    step := 1
    idleStableForMs := 0
    MouseGetPos &lastMouseX, &lastMouseY
    SetTimer(ProbeTimer, 100)
    Log("StartTest: Begin step 1")
    LblInstr.Text := "Step 1/2: Please keep idle (no mouse/keyboard) for ~3s, then MOVE the mouse."
    ResMouse.Text := "Mouse detection: pending"
    ResMouse.Opt("cGray")
    ResKey.Text := "Keyboard detection: pending"
    ResKey.Opt("cGray")
}

ResetTest() {
    global step, successMouse, successKeyboard, idleStableForMs
    global LblInstr, ResMouse, ResKey
    step := 0
    successMouse := false
    successKeyboard := false
    idleStableForMs := 0
    LblInstr.Text := "Click 'Start Test' to begin."
    ResMouse.Text := "Mouse detection: pending"
    ResMouse.Opt("cGray")
    ResKey.Text := "Keyboard detection: pending"
    ResKey.Opt("cGray")
    Log("ResetTest: state cleared")
}

StopTest() {
    global LblInstr
    SetTimer(ProbeTimer, 0)
    LblInstr.Text := "Stopped. Press 'Start Test' to run again."
    Log("StopTest: timer stopped")
}

ProbeTimer() {
    global lastMouseX, lastMouseY, lastIdlePhysical, lastActivity
    global step, successMouse, successKeyboard, idleStableForMs
    global LblIdle, LblMouse, LblLast, ResMouse, ResKey, LblInstr
    global IdleGateMs, moveThreshold
    
    ; Read current samples
    local mx := 0, my := 0
    MouseGetPos &mx, &my
    idle := A_TimeIdlePhysical

    ; Compute deltas
    dx := Abs(mx - lastMouseX)
    dy := Abs(my - lastMouseY)
    moved := (dx >= moveThreshold || dy >= moveThreshold)

    ; Update UI with live values
    LblIdle.Text := "IdlePhysical: " idle " ms"
    LblMouse.Text := "Mouse: x=" mx " y=" my "  (Δ=" dx "," dy ")"

    ; Detect event type
    evType := "none"
    if (moved) {
        evType := "mouse"
    } else if (idle < 100 && lastIdlePhysical >= 500) {
        ; idle reset without mouse move -> treat as keyboard
        evType := "keyboard"
    }

    if (evType != "none") {
        lastActivity := evType
        LblLast.Text := "LastActivity: " lastActivity
    }

    ; Step logic
    wasIdleLong := (lastIdlePhysical >= IdleGateMs)
    if (step = 1) {
        idleStableForMs := lastIdlePhysical
        if (wasIdleLong && evType = "mouse") {
            successMouse := true
            ResMouse.Text := "Mouse detection: SUCCESS"
            ResMouse.Opt("cGreen")
            SoundBeep(1000, 120)
            Log("Mouse success after idle: lastIdle=" lastIdlePhysical "ms dx=" dx " dy=" dy)
            ; advance
            step := 2
            idleStableForMs := 0
            LblInstr.Text := "Step 2/2: Please keep idle for ~3s, then TYPE any key (do not move mouse)."
        } else if (evType = "mouse" && !wasIdleLong) {
            Log("Mouse ignored (idle gate not met): lastIdle=" lastIdlePhysical "ms")
        }
    } else if (step = 2) {
        idleStableForMs := lastIdlePhysical
        if (wasIdleLong && evType = "keyboard") {
            successKeyboard := true
            ResKey.Text := "Keyboard detection: SUCCESS"
            ResKey.Opt("cGreen")
            SoundBeep(1400, 140)
            step := 3
            LblInstr.Text := "Done. Both detections succeeded. You can press F5 to test again or Esc to exit."
            Log("Keyboard success after idle: lastIdle=" lastIdlePhysical "ms")
        } else if (evType = "keyboard" && !wasIdleLong) {
            Log("Keyboard ignored (idle gate not met): lastIdle=" lastIdlePhysical "ms")
        }
    }

    ; Store for next tick
    lastMouseX := mx
    lastMouseY := my
    lastIdlePhysical := idle
}