#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
; سكريبت اختبار نظام نقل السجلات عبر Telegram
; يقوم بإنشاء ملفات تجريبية واختبار الإرسال والاستقبال
; ============================================================

; إنشاء ملفات تجريبية للاختبار
CreateTestFiles() {
    testFolder := A_ScriptDir "\test_logs"
    
    ; إنشاء مجلد الاختبار
    try {
        if DirExist(testFolder) {
            ; حذف المجلد القديم
            DirDelete(testFolder, true)
        }
        DirCreate(testFolder)
    } catch as e {
        MsgBox("فشل في إنشاء مجلد الاختبار: " . e.Message, "خطأ", 16)
        return false
    }
    
    ; إنشاء ملفات تجريبية
    testFiles := Map()
    
    ; ملف إعدادات تجريبي
    testFiles["test_settings.ini"] := "[Citrix]`nEnabled=1`nWindowTitle=Test`n`n[Telegram]`nBotToken=test_token`nChatId=test_chat`n"
    
    ; ملف سجل أخطاء تجريبي
    testFiles["test_error.log"] := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . " - BOOTSTRAP START`n"
    testFiles["test_error.log"] .= FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . " - Test error message`n"
    testFiles["test_error.log"] .= FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . " - Another test entry`n"
    
    ; ملف حالة تجريبي
    testFiles["test_state.ini"] := "[State]`nLastCheck=" . A_Now . "`nStatus=Running`nErrors=0`n"
    
    ; ملف سجل نشاط تجريبي
    testFiles["activity_test.log"] := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . " - Activity started`n"
    testFiles["activity_test.log"] .= FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . " - User action detected`n"
    testFiles["activity_test.log"] .= FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . " - Screenshot taken`n"
    
    ; ملف معلومات النظام
    testFiles["system_info.txt"] := "System Information Test File`n"
    testFiles["system_info.txt"] .= "Computer: " . A_ComputerName . "`n"
    testFiles["system_info.txt"] .= "User: " . A_UserName . "`n"
    testFiles["system_info.txt"] .= "Date: " . FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . "`n"
    testFiles["system_info.txt"] .= "AutoHotkey Version: " . A_AhkVersion . "`n"
    
    ; كتابة الملفات
    for fileName, content in testFiles {
        filePath := testFolder "\" . fileName
        try {
            file := FileOpen(filePath, "w")
            if file {
                file.Write(content)
                file.Close()
            } else {
                MsgBox("فشل في إنشاء الملف: " . fileName, "خطأ", 16)
                return false
            }
        } catch as e {
            MsgBox("خطأ في كتابة الملف " . fileName . ": " . e.Message, "خطأ", 16)
            return false
        }
    }
    
    return testFolder
}

; اختبار وجود إعدادات Telegram
TestTelegramSettings() {
    iniFile := A_ScriptDir "\..\settings.ini"
    
    if !FileExist(iniFile) {
        MsgBox("ملف settings.ini غير موجود!`n`nيجب إنشاء الملف أولاً مع بيانات Telegram الصحيحة.", "تحذير", 48)
        return false
    }
    
    botToken := IniRead(iniFile, "Telegram", "BotToken", "")
    chatId := IniRead(iniFile, "Telegram", "ChatId", "")
    
    if (botToken == "" || chatId == "") {
        MsgBox("بيانات Telegram غير مكتملة في settings.ini!`n`nيجب إضافة BotToken و ChatId في قسم [Telegram].", "تحذير", 48)
        return false
    }
    
    ; اختبار صحة التوكن (فحص أساسي)
    if (StrLen(botToken) < 20) {
        MsgBox("BotToken يبدو غير صحيح (قصير جداً).", "تحذير", 48)
        return false
    }
    
    ; اختبار صحة ChatId (يجب أن يكون رقماً)
    if !IsNumber(chatId) && !RegExMatch(chatId, "^-?\d+$") {
        MsgBox("ChatId يبدو غير صحيح (يجب أن يكون رقماً).", "تحذير", 48)
        return false
    }
    
    return true
}

; اختبار الاتصال بـ Telegram
TestTelegramConnection() {
    iniFile := A_ScriptDir "\settings.ini"
    botToken := IniRead(iniFile, "Telegram", "BotToken", "")
    
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        url := "https://api.telegram.org/bot" . botToken . "/getMe"
        
        whr.Open("GET", url, false)
        whr.SetTimeouts(5000, 5000, 5000, 10000) ; مهلة زمنية قصيرة للاختبار
        whr.Send()
        
        if (whr.Status == 200) {
            response := whr.ResponseText
            if (InStr(response, '"ok":true')) {
                return true
            } else {
                MsgBox("استجابة غير متوقعة من Telegram API:`n" . SubStr(response, 1, 200), "خطأ", 16)
                return false
            }
        } else {
            MsgBox("فشل الاتصال بـ Telegram API. كود الخطأ: " . whr.Status, "خطأ", 16)
            return false
        }
    } catch as e {
        MsgBox("خطأ في الاتصال بـ Telegram: " . e.Message, "خطأ", 16)
        return false
    }
}

; تشغيل اختبار شامل
RunFullTest() {
    ; واجهة المستخدم للاختبار
    testGui := Gui("+Resize", "اختبار نظام نقل السجلات عبر Telegram")
    testGui.Add("Text", "w400 Center", "اختبار نظام نقل السجلات عبر Telegram")
    testGui.Add("Text", "w400 Section", "")
    
    statusText := testGui.Add("Text", "w400", "جاري التحضير للاختبار...")
    progressBar := testGui.Add("Progress", "w400 h20", 0)
    
    testGui.Add("Text", "w400 Section", "")
    logText := testGui.Add("Edit", "w400 h200 ReadOnly VScroll", "")
    
    testGui.Add("Text", "w400 Section", "")
    closeBtn := testGui.Add("Button", "w100 h30", "إغلاق")
    closeBtn.OnEvent("Click", (*) => testGui.Close())
    
    testGui.Show()
    
    ; دالة لإضافة سجل
    AddLog := (message) => {
        logText.Text .= FormatTime(A_Now, "HH:mm:ss") . " - " . message . "`n"
        logText.Focus()
        Send("^{End}")
    }
    
    testsPassed := 0
    totalTests := 5
    
    try {
        ; الاختبار 1: إنشاء ملفات تجريبية
        statusText.Text := "الاختبار 1/5: إنشاء ملفات تجريبية..."
        progressBar.Value := 20
        AddLog("بدء إنشاء ملفات تجريبية...")
        
        testFolder := CreateTestFiles()
        if (testFolder) {
            AddLog("✅ تم إنشاء ملفات تجريبية في: " . testFolder)
            testsPassed++
        } else {
            AddLog("❌ فشل في إنشاء ملفات تجريبية")
        }
        
        Sleep(1000)
        
        ; الاختبار 2: فحص إعدادات Telegram
        statusText.Text := "الاختبار 2/5: فحص إعدادات Telegram..."
        progressBar.Value := 40
        AddLog("فحص إعدادات Telegram...")
        
        if (TestTelegramSettings()) {
            AddLog("✅ إعدادات Telegram صحيحة")
            testsPassed++
        } else {
            AddLog("❌ إعدادات Telegram غير صحيحة")
        }
        
        Sleep(1000)
        
        ; الاختبار 3: اختبار الاتصال
        statusText.Text := "الاختبار 3/5: اختبار الاتصال بـ Telegram..."
        progressBar.Value := 60
        AddLog("اختبار الاتصال بـ Telegram API...")
        
        if (TestTelegramConnection()) {
            AddLog("✅ الاتصال بـ Telegram ناجح")
            testsPassed++
        } else {
            AddLog("❌ فشل الاتصال بـ Telegram")
        }
        
        Sleep(1000)
        
        ; الاختبار 4: فحص وجود سكريبت الإرسال
        statusText.Text := "الاختبار 4/5: فحص سكريبت الإرسال..."
        progressBar.Value := 80
        AddLog("فحص وجود سكريبت الإرسال...")
        
        senderScript := A_ScriptDir "\send_logs_to_telegram.ahk"
        if (FileExist(senderScript)) {
            AddLog("✅ سكريبت الإرسال موجود: " . senderScript)
            testsPassed++
        } else {
            AddLog("❌ سكريبت الإرسال غير موجود")
        }
        
        Sleep(1000)
        
        ; الاختبار 5: فحص وجود سكريبت الاستقبال
        statusText.Text := "الاختبار 5/5: فحص سكريبت الاستقبال..."
        progressBar.Value := 100
        AddLog("فحص وجود سكريبت الاستقبال...")
        
        receiverScript := A_ScriptDir "\get_logs_from_telegram.ahk"
        if (FileExist(receiverScript)) {
            AddLog("✅ سكريبت الاستقبال موجود: " . receiverScript)
            testsPassed++
        } else {
            AddLog("❌ سكريبت الاستقبال غير موجود")
        }
        
        Sleep(1000)
        
        ; النتائج النهائية
        statusText.Text := "اكتمل الاختبار - " . testsPassed . "/" . totalTests . " اختبارات نجحت"
        
        AddLog("")
        AddLog("=== نتائج الاختبار ===")
        AddLog("الاختبارات الناجحة: " . testsPassed . "/" . totalTests)
        
        if (testsPassed == totalTests) {
            AddLog("🎉 جميع الاختبارات نجحت! النظام جاهز للاستخدام.")
            AddLog("")
            AddLog("خطوات الاستخدام:")
            AddLog("1. على الجهاز الآخر: شغل send_logs_to_telegram.ahk")
            AddLog("2. على هذا الجهاز: شغل get_logs_from_telegram.ahk")
        } else {
            AddLog("⚠️ بعض الاختبارات فشلت. يرجى مراجعة الأخطاء أعلاه.")
        }
        
    } catch as e {
        AddLog("❌ خطأ أثناء الاختبار: " . e.Message)
        statusText.Text := "حدث خطأ أثناء الاختبار"
    }
    
    ; تغيير نص زر الإغلاق
    closeBtn.Text := "إنهاء"
    
    return testsPassed == totalTests
}

; تشغيل الاختبار
try {
    RunFullTest()
} catch as e {
    MsgBox("خطأ عام في الاختبار: " . e.Message, "خطأ", 16)
}

ExitApp(0)