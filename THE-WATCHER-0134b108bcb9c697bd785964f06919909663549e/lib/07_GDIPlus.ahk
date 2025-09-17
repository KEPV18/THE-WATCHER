; ============================================================
; 07_GDIPlus.ahk - GDI+ Helper Functions
; Handles all low-level bitmap and image operations.
; ============================================================

; Make GdiplusToken global so Startup and Shutdown can share it.
global GdiplusToken := 0

Gdip_Startup() {
    global GdiplusToken
    if (GdiplusToken)
        return
    
    GdiplusStartupInput := Buffer(24, 0)
    NumPut("UInt", 1, GdiplusStartupInput, 0) ; GdiplusVersion
    
    if DllCall("gdiplus\GdiplusStartup", "Ptr*", &GdiplusToken, "Ptr", GdiplusStartupInput, "Ptr", 0) != 0 {
        MsgBox("GDI+ failed to start.", "GDI+ Error", 4112)
        ExitApp
    }
}

Gdip_Shutdown(*) {
    global GdiplusToken
    if (GdiplusToken) {
        DllCall("gdiplus\GdiplusShutdown", "Ptr", GdiplusToken)
        GdiplusToken := 0
    }
}

CaptureAreaBitmap(X, Y, W, H) {
    if (W <= 0 || H <= 0)
        return 0
    
    hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
    hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
    hbm := DllCall("CreateCompatibleBitmap", "Ptr", hdcScreen, "Int", W, "Int", H, "Ptr")
    hbmOld := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hbm, "Ptr")
    
    DllCall("BitBlt", "Ptr", hdcMem, "Int", 0, "Int", 0, "Int", W, "Int", H, "Ptr", hdcScreen, "Int", X, "Int", Y, "UInt", 0x00CC0020)
    
    DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hbmOld)
    DllCall("DeleteDC", "Ptr", hdcMem)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)
    
    return hbm
}

Gdip_SaveBitmapToFile(hBitmap, sFile) {
    pBitmap := 0
    DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", hBitmap, "Ptr", 0, "Ptr*", &pBitmap)
    if !pBitmap
        return false

    CLSID_PNG := "{557CF406-1A04-11D3-9A73-0000F81EF32E}"
    pEncoderClsid := Buffer(16)
    DllCall("ole32\CLSIDFromString", "WStr", CLSID_PNG, "Ptr", pEncoderClsid)
    
    status := DllCall("gdiplus\GdipSaveImageToFile", "Ptr", pBitmap, "WStr", sFile, "Ptr", pEncoderClsid, "Ptr", 0)
    
    DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)
    
    return status = 0
}

Gdip_CreateBitmapFromFile(sFile) {
    pBitmap := 0
    DllCall("gdiplus\GdipCreateBitmapFromFile", "WStr", sFile, "Ptr*", &pBitmap)
    return pBitmap
}

Gdip_GetImageWidth(pBitmap) {
    Width := 0
    if pBitmap
        DllCall("gdiplus\GdipGetImageWidth", "Ptr", pBitmap, "UInt*", &Width)
    return Width
}

Gdip_GetImageHeight(pBitmap) {
    Height := 0
    if pBitmap
        DllCall("gdiplus\GdipGetImageHeight", "Ptr", pBitmap, "UInt*", &Height)
    return Height
}

Gdip_DisposeImage(pBitmap) {
    if pBitmap
        DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)
}
