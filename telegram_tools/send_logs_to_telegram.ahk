#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
; سكريبت إرسال السجلات عبر Telegram
; استخدم هذا السكريبت على الجهاز الآخر لإرسال جميع السجلات
; ============================================================

; تحميل الإعدادات
global BOT_TOKEN := ""
global CHAT_ID := ""
global iniFile := A_ScriptDir "\..\settings.ini"
global logFile := A_ScriptDir "\sender_log.txt"

; دالة التسجيل المفصلة
WriteLog(message, level := "INFO") {
    global logFile
    
    timestamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    logEntry := "[" . timestamp . "] [" . level . "] " . message . "`n"
    
    try {
        file := FileOpen(logFile, "a")
        if (file) {
            file.Write(logEntry)
            file.Close()
        }
    } catch as e {
        ; إذا فشل التسجيل، اعرض رسالة خطأ
        MsgBox("خطأ في كتابة السجل: " . e.Message, "خطأ", "OK Icon!")
    }
}

; تحميل بيانات Telegram من settings.ini
LoadTelegramSettings() {
    global BOT_TOKEN, CHAT_ID, iniFile
    
    WriteLog("بدء تحميل إعدادات Telegram من: " . iniFile)
    
    if !FileExist(iniFile) {
        WriteLog("ملف الإعدادات غير موجود: " . iniFile, "ERROR")
        MsgBox("ملف الإعدادات غير موجود!`n" . iniFile, "خطأ", "OK Icon!")
        return false
    }
    
    try {
        BOT_TOKEN := IniRead(iniFile, "Telegram", "BotToken", "")
        CHAT_ID := IniRead(iniFile, "Telegram", "ChatId", "")
        
        if (BOT_TOKEN == "" || CHAT_ID == "") {
            WriteLog("بيانات Telegram فارغة في ملف الإعدادات", "ERROR")
            MsgBox("بيانات Telegram غير مكتملة في ملف الإعدادات!", "خطأ", "OK Icon!")
            return false
        }
        
        WriteLog("تم تحميل إعدادات Telegram بنجاح - Chat ID: " . CHAT_ID)
        return true
        
    } catch as e {
        WriteLog("خطأ في قراءة ملف الإعدادات: " . e.Message, "ERROR")
        MsgBox("خطأ في قراءة ملف الإعدادات: " . e.Message, "خطأ", "OK Icon!")
        return false
    }
}

; إرسال رسالة عبر Telegram باستخدام WinHTTP
SendTelegramMessage(message) {
    global BOT_TOKEN, CHAT_ID
    
    try {
        WriteLog("بناء رسالة Telegram - الطول: " . StrLen(message))
        
        ; إنشاء كائن WinHTTP
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        
        ; تحضير الرابط
        url := "https://api.telegram.org/bot" . BOT_TOKEN . "/sendMessage"
        WriteLog("URL المستخدم: " . url)
        
        ; فتح الاتصال
        http.Open("POST", url, false)
        
        ; تعيين الترويسات مع ترميز UTF-8
        http.SetRequestHeader("Content-Type", "application/x-www-form-urlencoded; charset=UTF-8")
        http.SetRequestHeader("User-Agent", "AutoHotkey/2.0")
        
        ; تحضير البيانات مع ترميز UTF-8 صحيح
        data := "chat_id=" . CHAT_ID . "&text=" . UrlEncode(message) . "&parse_mode=HTML"
        WriteLog("البيانات المرسلة جاهزة - Chat ID: " . CHAT_ID)
        
        WriteLog("جاري إرسال الرسالة...")
        
        ; إرسال الطلب
        http.Send(data)
        
        ; التحقق من الاستجابة
        responseStatus := http.Status
        responseText := http.ResponseText
        
        WriteLog("الاستجابة وصلت - الكود: " . responseStatus)
        WriteLog("نص الاستجابة: " . responseText)
        
        if (responseStatus = 200) {
            if InStr(responseText, '"ok":true') {
                WriteLog("تم إرسال الرسالة بنجاح")
                return true
            } else {
                WriteLog("فشل إرسال الرسالة", "ERROR")
                WriteLog("تفاصيل الخطأ: " . responseText, "ERROR")
                return false
            }
        } else {
            WriteLog("فشل في إرسال الرسالة - رمز الخطأ: " . responseStatus, "ERROR")
            WriteLog("رسالة الخطأ: " . responseText, "ERROR")
            return false
        }
    } catch as e {
        WriteLog("خطأ في إرسال الرسالة: " . e.Message, "ERROR")
        return false
    }
}

; إرسال ملف عبر Telegram (مبسط مع تسجيل)
SendTelegramFile(filePath, caption := "") {
    global BOT_TOKEN, CHAT_ID
    
    WriteLog("محاولة إرسال ملف: " . filePath)
    
    if !FileExist(filePath) {
        WriteLog("الملف غير موجود: " . filePath, "ERROR")
        return false
    }
    
    try {
        WriteLog("بدء قراءة الملف...")
        ; قراءة الملف مع ترميز UTF-8
        file := FileOpen(filePath, "r", "UTF-8")
        if !file {
            WriteLog("فشل في فتح الملف للقراءة", "ERROR")
            return false
        }
        
        content := file.Read()
        file.Close()
        
        WriteLog("تم قراءة الملف - الحجم: " . StrLen(content) . " حرف")
        
        ; إرسال كرسالة نصية إذا كان الملف صغير
        if (StrLen(content) < 4000) {
            SplitPath(filePath, &fileName)
            message := "📄 <b>" . fileName . "</b>`n`n<pre>" . content . "</pre>"
            WriteLog("إرسال الملف كرسالة واحدة")
            return SendTelegramMessage(message)
        } else {
            ; إرسال كرسالة مقسمة للملفات الكبيرة
            SplitPath(filePath, &fileName)
            message := "📄 <b>" . fileName . "</b> (ملف كبير - مقسم)`n`n"
            
            WriteLog("تقسيم الملف الكبير...")
            ; تقسيم المحتوى
            chunks := []
            pos := 1
            while (pos <= StrLen(content)) {
                chunk := SubStr(content, pos, 3500)
                chunks.Push(chunk)
                pos += 3500
            }
            
            WriteLog("تم تقسيم الملف إلى " . chunks.Length . " جزء")
            
            ; إرسال الرأس
            result := SendTelegramMessage(message . "الجزء 1/" . chunks.Length . ":`n<pre>" . chunks[1] . "</pre>")
            if !result {
                WriteLog("فشل في إرسال الجزء الأول", "ERROR")
                return false
            }
            
            ; إرسال باقي الأجزاء
            for i, chunk in chunks {
                if (i > 1) {
                    WriteLog("إرسال الجزء " . i . "/" . chunks.Length)
                    Sleep(1000)
                    result := SendTelegramMessage("الجزء " . i . "/" . chunks.Length . ":`n<pre>" . chunk . "</pre>")
                    if !result {
                        WriteLog("فشل في إرسال الجزء " . i, "ERROR")
                        return false
                    }
                }
            }
            
            WriteLog("تم إرسال جميع أجزاء الملف بنجاح")
            return true
        }
        
    } catch as e {
        WriteLog("خطأ في معالجة الملف: " . e.Message, "ERROR")
        return false
    }
}

; دالة ترميز URL للنص العربي والرموز الخاصة (محدثة لتطابق النظام الرئيسي)
UrlEncode(str, encoding := "UTF-8") {
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



; جمع معلومات النظام
CollectSystemInfo() {
    WriteLog("جمع معلومات النظام...")
    info := "🖥️ <b>معلومات النظام</b>`n"
    info .= "📅 التاريخ: " . FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . "`n"
    info .= "💻 الكمبيوتر: " . A_ComputerName . "`n"
    info .= "👤 المستخدم: " . A_UserName . "`n"
    info .= "🔧 AutoHotkey: " . A_AhkVersion . "`n"
    info .= "🖥️ نظام التشغيل: " . A_OSVersion . "`n"
    info .= "📺 دقة الشاشة: " . A_ScreenWidth . "x" . A_ScreenHeight . "`n"
    info .= "📁 مجلد السكريبت: " . A_ScriptDir . "`n"
    WriteLog("تم جمع معلومات النظام")
    return info
}

; الدالة الرئيسية
main() {
    WriteLog("بدء تشغيل سكريبت الإرسال")
    
    ; تحميل إعدادات Telegram
    if !LoadTelegramSettings() {
        WriteLog("فشل في تحميل إعدادات Telegram", "ERROR")
        return
    }
    
    WriteLog("تم تحميل الإعدادات بنجاح")
    
    ; البحث عن ملفات السجل
    logFiles := []
    
    WriteLog("البحث عن ملفات السجل...")
    
    ; البحث في المجلد الرئيسي
    Loop Files, A_ScriptDir "\..\logs\*.txt" {
        logFiles.Push(A_LoopFileFullPath)
        WriteLog("تم العثور على ملف: " . A_LoopFileName)
    }
    
    ; البحث في مجلد logs إضافي
    Loop Files, A_ScriptDir "\logs\*.txt" {
        logFiles.Push(A_LoopFileFullPath)
        WriteLog("تم العثور على ملف: " . A_LoopFileName)
    }
    
    WriteLog("تم العثور على " . logFiles.Length . " ملف سجل")
    
    if (logFiles.Length = 0) {
        WriteLog("لم يتم العثور على أي ملفات سجل", "WARNING")
        return
    }
    
    ; إرسال كل ملف
    successCount := 0
    for filePath in logFiles {
        WriteLog("محاولة إرسال: " . filePath)
        if SendTelegramFile(filePath) {
            successCount++
            WriteLog("تم إرسال الملف بنجاح: " . filePath)
        } else {
            WriteLog("فشل في إرسال الملف: " . filePath, "ERROR")
        }
        Sleep(2000) ; انتظار بين الملفات
    }
    
    WriteLog("انتهى الإرسال - تم إرسال " . successCount . " من " . logFiles.Length . " ملف")
    WriteLog("انتهى تشغيل سكريبت الإرسال")
}

; تشغيل السكريبت
try {
    main()
} catch as e {
    WriteLog("خطأ عام: " . e.Message, "ERROR")
    MsgBox("خطأ عام: " . e.Message, "خطأ", 16)
}

ExitApp(0)