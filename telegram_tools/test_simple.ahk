; اختبار بسيط لإرسال رسالة Telegram
#NoEnv
#SingleInstance Force

; إعدادات Telegram
BOT_TOKEN := "8328100113:AAEEtm8w7Em7eqSVSjq8yiG5nPu7JNBz9Nk"
CHAT_ID := "5670001305"

; دالة ترميز URL للنص العربي
UrlEncode(str) {
    encoded := ""
    Loop Parse, str {
        char := A_LoopField
        if (char ~= "[A-Za-z0-9\-_.~]") {
            encoded .= char
        } else {
            ; ترميز UTF-8 للأحرف العربية والخاصة
            charCode := Ord(char)
            if (charCode <= 0x7F) {
                encoded .= "%" . Format("{:02X}", charCode)
            } else if (charCode <= 0x7FF) {
                encoded .= "%" . Format("{:02X}", 0xC0 | (charCode >> 6))
                encoded .= "%" . Format("{:02X}", 0x80 | (charCode & 0x3F))
            } else if (charCode <= 0xFFFF) {
                encoded .= "%" . Format("{:02X}", 0xE0 | (charCode >> 12))
                encoded .= "%" . Format("{:02X}", 0x80 | ((charCode >> 6) & 0x3F))
                encoded .= "%" . Format("{:02X}", 0x80 | (charCode & 0x3F))
            } else {
                encoded .= "%" . Format("{:02X}", 0xF0 | (charCode >> 18))
                encoded .= "%" . Format("{:02X}", 0x80 | ((charCode >> 12) & 0x3F))
                encoded .= "%" . Format("{:02X}", 0x80 | ((charCode >> 6) & 0x3F))
                encoded .= "%" . Format("{:02X}", 0x80 | (charCode & 0x3F))
            }
        }
    }
    return encoded
}

; اختبار إرسال رسالة بسيطة
message := "اختبار الترميز العربي - Test Arabic Encoding"

try {
    ; إنشاء كائن WinHTTP
http := ComObject("WinHttp.WinHttpRequest.5.1")
    
    ; تحضير الرابط
    url := "https://api.telegram.org/bot" . BOT_TOKEN . "/sendMessage"
    
    ; فتح الاتصال
    http.Open("POST", url, false)
    
    ; تعيين الترويسات مع ترميز UTF-8
    http.SetRequestHeader("Content-Type", "application/x-www-form-urlencoded; charset=UTF-8")
    
    ; تحضير البيانات مع ترميز URL
    data := "chat_id=" . CHAT_ID . "&text=" . UrlEncode(message)
    
    ; إرسال الطلب
    http.Send(data)
    
    ; التحقق من الاستجابة
    responseStatus := http.Status
    responseText := http.ResponseText
    
    MsgBox, Response Status: %responseStatus%`nResponse: %responseText%
    
} catch e {
    MsgBox, Error: %e.message%
}