#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
; سكريبت استقبال السجلات من Telegram
; استخدم هذا السكريبت على هذا الجهاز لاستقبال السجلات
; ============================================================

; تحميل الإعدادات
global BOT_TOKEN := ""
global CHAT_ID := ""
global iniFile := A_ScriptDir "\.\..\settings.ini"
global lastUpdateId := 0
global downloadFolder := A_ScriptDir "\received_logs"
global logFile := A_ScriptDir "\receiver_log.txt"

; دالة كتابة السجل
WriteLog(message, level := "INFO") {
    try {
        timestamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        logEntry := "[" . timestamp . "] [" . level . "] " . message . "`n"
        
        ; كتابة السجل
        FileAppend(logEntry, logFile, "UTF-8")
    } catch as e {
        ; في حالة فشل كتابة السجل، عرض رسالة خطأ
        MsgBox("فشل في كتابة السجل: " . e.Message, "خطأ في السجل", 16)
    }
}

; تحميل بيانات Telegram من settings.ini
LoadTelegramSettings() {
    global BOT_TOKEN, CHAT_ID, iniFile, lastUpdateId
    
    WriteLog("بدء تحميل إعدادات Telegram...")
    
    if !FileExist(iniFile) {
        WriteLog("ملف الإعدادات غير موجود: " . iniFile, "ERROR")
        return false
    }
    
    try {
        BOT_TOKEN := IniRead(iniFile, "Telegram", "BotToken", "")
        CHAT_ID := IniRead(iniFile, "Telegram", "ChatId", "")
        
        ; قراءة آخر معرف تحديث محفوظ
        lastUpdateId := IniRead(iniFile, "Telegram", "LastUpdateId", "0")
        if (lastUpdateId == "ERROR" || lastUpdateId == "") {
            lastUpdateId := 0
        } else {
            lastUpdateId := Integer(lastUpdateId)
        }
        
        if (BOT_TOKEN == "" || CHAT_ID == "") {
            WriteLog("بيانات Telegram فارغة أو غير مكتملة", "ERROR")
            return false
        }
        
        WriteLog("تم تحميل إعدادات Telegram بنجاح - Chat ID: " . CHAT_ID . ", Last Update ID: " . lastUpdateId)
        return true
        
    } catch as e {
        WriteLog("خطأ في قراءة ملف الإعدادات: " . e.Message, "ERROR")
        return false
    }
}

; إنشاء مجلد التحميل
CreateDownloadFolder() {
    global downloadFolder
    
    WriteLog("بدء إنشاء مجلد التحميل...")
    
    ; إنشاء مجلد بالتاريخ والوقت
    timestamp := FormatTime(A_Now, "yyyy-MM-dd_HH-mm-ss")
    downloadFolder := A_ScriptDir "\received_logs_" . timestamp
    
    WriteLog("مسار مجلد التحميل: " . downloadFolder)
    
    try {
        DirCreate(downloadFolder)
        WriteLog("تم إنشاء مجلد التحميل بنجاح")
        return true
    } catch as e {
        WriteLog("فشل في إنشاء مجلد التحميل: " . e.Message, "ERROR")
        return false
    }
}

; الحصول على التحديثات من Telegram
GetTelegramUpdates() {
    global BOT_TOKEN, lastUpdateId
    
    WriteLog("طلب التحديثات من Telegram...")
    WriteLog("آخر معرف تحديث: " . lastUpdateId)
    
    url := "https://api.telegram.org/bot" . BOT_TOKEN . "/getUpdates"
    if (lastUpdateId > 0) {
        url .= "?offset=" . (lastUpdateId + 1)
        WriteLog("استخدام offset: " . (lastUpdateId + 1))
    }
    
    try {
        WriteLog("إرسال طلب HTTP إلى: " . url)
        
        ; إنشاء كائن HTTP
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.Open("GET", url, false)
        http.SetRequestHeader("Content-Type", "application/json")
        
        WriteLog("إرسال الطلب...")
        http.Send()
        
        WriteLog("حالة الاستجابة: " . http.Status)
        
        if (http.Status != 200) {
            WriteLog("فشل في الطلب - كود الحالة: " . http.Status, "ERROR")
            return false
        }
        
        response := http.ResponseText
        WriteLog("تم استلام الاستجابة - الحجم: " . StrLen(response) . " حرف")
        
        ; تحليل JSON بسيط
        if (InStr(response, '"ok":true')) {
            WriteLog("الاستجابة صحيحة")
            return response
        } else {
            WriteLog("استجابة خاطئة من Telegram: " . SubStr(response, 1, 200), "ERROR")
            return false
        }
        
    } catch as e {
        WriteLog("خطأ في طلب التحديثات: " . e.Message, "ERROR")
        return false
    }
}

; تحميل ملف من Telegram
DownloadTelegramFile(fileId, fileName) {
    global BOT_TOKEN, downloadFolder
    
    WriteLog("بدء تحميل ملف: " . fileName . " (ID: " . fileId . ")")
    
    try {
        ; الحصول على مسار الملف
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        url := "https://api.telegram.org/bot" . BOT_TOKEN . "/getFile?file_id=" . fileId
        
        WriteLog("إرسال طلب للحصول على معلومات الملف...")
        whr.Open("GET", url, false)
        whr.Send()
        
        if (whr.Status != 200) {
            WriteLog("فشل في الحصول على معلومات الملف. كود الحالة: " . whr.Status, "ERROR")
            return false
        }
        
        WriteLog("تم الحصول على معلومات الملف بنجاح")
        
        ; تحليل الاستجابة للحصول على file_path
        response := whr.ResponseText
        WriteLog("حجم استجابة معلومات الملف: " . StrLen(response) . " حرف")
        
        ; استخراج file_path من JSON (طريقة مبسطة)
        if (RegExMatch(response, '"file_path":"([^"]+)"', &match)) {
            filePath := match[1]
            WriteLog("مسار الملف على الخادم: " . filePath)
            
            ; تحميل الملف
            downloadUrl := "https://api.telegram.org/file/bot" . BOT_TOKEN . "/" . filePath
            WriteLog("بدء تحميل الملف من: " . downloadUrl)
            
            whr2 := ComObject("WinHttp.WinHttpRequest.5.1")
            whr2.Open("GET", downloadUrl, false)
            whr2.Send()
            
            if (whr2.Status == 200) {
                WriteLog("تم تحميل الملف بنجاح. حجم الملف: " . StrLen(whr2.ResponseText) . " حرف")
                
                ; حفظ الملف
                localPath := downloadFolder "\" . fileName
                WriteLog("حفظ الملف في: " . localPath)
                
                ; إنشاء المجلدات الفرعية إذا لزم الأمر
                SplitPath(localPath, , &dir)
                if !DirExist(dir) {
                    WriteLog("إنشاء مجلد فرعي: " . dir)
                    DirCreate(dir)
                }
                
                file := FileOpen(localPath, "w")
                if file {
                    file.Write(whr2.ResponseText)
                    file.Close()
                    WriteLog("تم حفظ الملف بنجاح: " . fileName)
                    return true
                } else {
                    WriteLog("فشل في فتح الملف للكتابة: " . localPath, "ERROR")
                }
            } else {
                WriteLog("فشل في تحميل الملف. كود الحالة: " . whr2.Status, "ERROR")
            }
        } else {
            WriteLog("فشل في استخراج مسار الملف من الاستجابة", "ERROR")
        }
        
        return false
    } catch as e {
        WriteLog("خطأ في تحميل الملف " . fileName . ": " . e.Message, "ERROR")
        return false
    }
}

; معالجة رسالة واحدة (مبسط)
ProcessMessage(messageObj) {
    global downloadFolder, lastUpdateId, iniFile
    
    WriteLog("بدء معالجة رسالة...")
    
    ; تحديث آخر update_id
    if (messageObj.HasProp("update_id")) {
        newUpdateId := messageObj.update_id
        if (newUpdateId > lastUpdateId) {
            lastUpdateId := newUpdateId
            WriteLog("تحديث آخر ID: " . lastUpdateId)
            
            ; حفظ آخر معرف تحديث فوراً
            try {
                IniWrite(lastUpdateId, iniFile, "Telegram", "LastUpdateId")
                WriteLog("تم حفظ آخر معرف تحديث: " . lastUpdateId)
            } catch as e {
                WriteLog("فشل في حفظ آخر معرف تحديث: " . e.Message, "ERROR")
            }
        }
    }
    
    ; التحقق من وجود رسالة
    if (!messageObj.HasProp("message")) {
        WriteLog("لا توجد رسالة في التحديث")
        return false
    }
    
    message := messageObj.message
    WriteLog("تم العثور على رسالة")
    
    ; معالجة الرسائل النصية التي تحتوي على ملفات
    if (message.HasProp("text")) {
        text := message.text
        WriteLog("نص الرسالة: " . StrLen(text) . " حرف")
        
        ; البحث عن رسائل تحتوي على ملفات (تبدأ بـ 📄)
        if (InStr(text, "📄") > 0) {
            WriteLog("تم العثور على رسالة تحتوي على ملف")
            
            ; استخراج اسم الملف
            fileName := ""
            if (RegExMatch(text, "📄 <b>(.*?)</b>", &match)) {
                fileName := match[1]
                WriteLog("اسم الملف المستخرج: " . fileName)
            } else {
                WriteLog("فشل في استخراج اسم الملف", "ERROR")
            }
            
            ; استخراج المحتوى من بين <pre> و </pre>
            if (RegExMatch(text, "<pre>(.*?)</pre>", &match)) {
                content := match[1]
                WriteLog("تم استخراج محتوى الملف. الحجم: " . StrLen(content) . " حرف")
                
                ; حفظ الملف
                if (fileName != "" && content != "") {
                    filePath := downloadFolder "\" fileName
                    WriteLog("حفظ الملف في: " . filePath)
                    
                    ; إذا كان الملف موجود، أضف المحتوى إليه (للملفات المقسمة)
                    if (FileExist(filePath)) {
                        WriteLog("الملف موجود، إضافة المحتوى إليه")
                        file := FileOpen(filePath, "a")
                        if (file) {
                            file.Write(content)
                            file.Close()
                            WriteLog("تم إضافة المحتوى للملف الموجود")
                        } else {
                            WriteLog("فشل في فتح الملف للإضافة", "ERROR")
                        }
                    } else {
                        WriteLog("إنشاء ملف جديد")
                        file := FileOpen(filePath, "w")
                        if (file) {
                            file.Write(content)
                            file.Close()
                            WriteLog("تم إنشاء الملف وحفظ المحتوى")
                        } else {
                            WriteLog("فشل في إنشاء الملف الجديد", "ERROR")
                        }
                    }
                    
                    ; كتابة سجل التحميل
                    logFile := downloadFolder "\download_log.txt"
                    logEntry := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . " - تم حفظ: " . fileName . "`n"
                    
                    try {
                        file := FileOpen(logFile, "a")
                        if file {
                            file.Write(logEntry)
                            file.Close()
                            WriteLog("تم تسجيل عملية التحميل في سجل التحميل")
                        }
                    } catch as e {
                        WriteLog("فشل في كتابة سجل التحميل: " . e.Message, "ERROR")
                    }
                    
                    return true
                } else {
                    WriteLog("اسم الملف أو المحتوى فارغ", "ERROR")
                }
            } else {
                WriteLog("فشل في استخراج محتوى الملف", "ERROR")
            }
        } else {
            WriteLog("الرسالة لا تحتوي على ملف")
        }
    } else {
        WriteLog("الرسالة لا تحتوي على نص")
    }
    
    return false
}

; تحليل JSON مبسط
ParseSimpleJSON(jsonStr) {
    ; هذه دالة مبسطة جداً لتحليل JSON
    ; في التطبيق الحقيقي نحتاج مكتبة أكثر تعقيداً
    
    results := []
    
    ; البحث عن الرسائل
    pos := 1
    while (pos := InStr(jsonStr, '"update_id":', pos)) {
        ; استخراج update_id
        updateIdStart := pos + 12
        updateIdEnd := InStr(jsonStr, ",", updateIdStart)
        if (updateIdEnd == 0) {
            updateIdEnd := InStr(jsonStr, "}", updateIdStart)
        }
        
        if (updateIdEnd > updateIdStart) {
            updateId := SubStr(jsonStr, updateIdStart, updateIdEnd - updateIdStart)
            updateId := Trim(updateId, " `t`n`r")
            
            ; إنشاء كائن مبسط
            msgObj := {update_id: Integer(updateId)}
            
            ; البحث عن document في نفس الرسالة
            docPos := InStr(jsonStr, '"document":', pos)
            nextUpdatePos := InStr(jsonStr, '"update_id":', pos + 1)
            
            if (docPos > 0 && (nextUpdatePos == 0 || docPos < nextUpdatePos)) {
                ; استخراج معلومات الملف
                fileIdMatch := RegExMatch(jsonStr, '"file_id":"([^"]+)"', &fileIdResult, docPos)
                fileNameMatch := RegExMatch(jsonStr, '"file_name":"([^"]+)"', &fileNameResult, docPos)
                
                if (fileIdMatch) {
                    msgObj.message := {
                        document: {
                            file_id: fileIdResult[1],
                            file_name: fileNameMatch ? fileNameResult[1] : "unknown"
                        }
                    }
                }
            }
            
            results.Push(msgObj)
        }
        
        pos := updateIdEnd
    }
    
    return results
}

; معالجة التحديثات وحفظ الملفات
ProcessUpdates(response) {
    global lastUpdateId, downloadFolder
    
    WriteLog("بدء معالجة التحديثات...")
    
    ; إنشاء مجلد التحميل إذا لم يكن موجوداً
    if !DirExist(downloadFolder) {
        WriteLog("إنشاء مجلد التحميل: " . downloadFolder)
        try {
            DirCreate(downloadFolder)
            WriteLog("تم إنشاء مجلد التحميل بنجاح")
        } catch as e {
            WriteLog("فشل في إنشاء مجلد التحميل: " . e.Message, "ERROR")
            return false
        }
    }
    
    ; تحليل JSON بسيط للعثور على الرسائل
    messageCount := 0
    savedFiles := 0
    
    ; البحث عن update_id لتحديث آخر معرف
    pos := 1
    while (pos := InStr(response, '"update_id":', pos)) {
        pos += 12
        endPos := InStr(response, ",", pos)
        if (endPos = 0) {
            endPos := InStr(response, "}", pos)
        }
        if (endPos > pos) {
            updateId := SubStr(response, pos, endPos - pos)
            updateId := Trim(updateId, ' "')
            if (updateId > lastUpdateId) {
                lastUpdateId := updateId
                WriteLog("تحديث آخر معرف: " . lastUpdateId)
            }
        }
        pos := endPos
    }
    
    ; البحث عن الرسائل النصية
    pos := 1
    while (pos := InStr(response, '"text":', pos)) {
        messageCount++
        WriteLog("معالجة الرسالة رقم: " . messageCount)
        
        pos += 7
        ; العثور على بداية النص
        if (SubStr(response, pos, 1) = '"') {
            pos++
            textStart := pos
            
            ; العثور على نهاية النص
            textEnd := InStr(response, '"', textStart)
            if (textEnd > textStart) {
                messageText := SubStr(response, textStart, textEnd - textStart)
                
                ; فك تشفير escape characters
                messageText := StrReplace(messageText, '\n', "`n")
                messageText := StrReplace(messageText, '\r', "`r")
                messageText := StrReplace(messageText, '\"', '"')
                messageText := StrReplace(messageText, '\\', '\')
                
                WriteLog("طول النص: " . StrLen(messageText) . " حرف")
                
                ; حفظ الرسالة كملف
                fileName := "telegram_message_" . FormatTime(A_Now, "yyyyMMdd_HHmmss") . "_" . messageCount . ".txt"
                filePath := downloadFolder . "\" . fileName
                
                try {
                    WriteLog("حفظ الملف: " . fileName)
                    FileAppend(messageText, filePath, "UTF-8")
                    savedFiles++
                    WriteLog("تم حفظ الملف بنجاح: " . fileName)
                } catch as e {
                    WriteLog("فشل في حفظ الملف " . fileName . ": " . e.Message, "ERROR")
                }
            }
        }
        pos := textEnd + 1
    }
    
    WriteLog("انتهت المعالجة - الرسائل: " . messageCount . "، الملفات المحفوظة: " . savedFiles)
    
    ; حفظ آخر معرف تحديث في ملف الإعدادات
    if (lastUpdateId > 0) {
        try {
            IniWrite(lastUpdateId, iniFile, "Telegram", "LastUpdateId")
            WriteLog("تم حفظ آخر معرف تحديث: " . lastUpdateId)
        } catch as e {
            WriteLog("فشل في حفظ آخر معرف تحديث: " . e.Message, "ERROR")
        }
    }
    
    if (savedFiles > 0) {
        WriteLog("تم حفظ " . savedFiles . " ملف في: " . downloadFolder)
        return true
    } else {
        WriteLog("لم يتم العثور على رسائل جديدة", "WARNING")
        return false
    }
}

; الدالة الرئيسية
main() {
    WriteLog("بدء تشغيل سكريبت الاستقبال")
    
    ; تحميل إعدادات Telegram
    if !LoadTelegramSettings() {
        WriteLog("فشل في تحميل إعدادات Telegram", "ERROR")
        MsgBox("فشل في تحميل إعدادات Telegram! تحقق من ملف settings.ini", "خطأ", 16)
        return
    }
    
    WriteLog("تم تحميل الإعدادات بنجاح")
    
    ; البحث عن الرسائل وتحميلها
    WriteLog("بدء البحث عن الرسائل...")
    
    ; الحصول على التحديثات
    response := GetTelegramUpdates()
    if (!response) {
        WriteLog("فشل في الحصول على التحديثات من Telegram", "ERROR")
        MsgBox("فشل في الاتصال بـ Telegram! تحقق من الاتصال بالإنترنت والإعدادات.", "خطأ", 16)
        return
    }
    
    WriteLog("تم الحصول على التحديثات بنجاح")
    
    ; معالجة التحديثات
    if (ProcessUpdates(response)) {
        WriteLog("تم تحميل الملفات بنجاح")
        MsgBox("تم تحميل الملفات بنجاح!`n`nتحقق من مجلد: " . downloadFolder, "نجح", 64)
    } else {
        WriteLog("لم يتم العثور على ملفات جديدة", "WARNING")
        MsgBox("لم يتم العثور على رسائل جديدة للتحميل.", "معلومات", 64)
    }
    
    WriteLog("انتهى تشغيل سكريبت الاستقبال")
}

; تشغيل السكريبت
try {
    ; إنشاء مجلد التحميل
    if (!CreateDownloadFolder()) {
        WriteLog("فشل في إنشاء مجلد التحميل", "ERROR")
        ExitApp(1)
    }
    
    ; تشغيل الدالة الرئيسية
    main()
} catch as e {
    WriteLog("خطأ عام: " . e.Message, "ERROR")
    MsgBox("خطأ عام: " . e.Message, "خطأ", 16)
}

ExitApp(0)