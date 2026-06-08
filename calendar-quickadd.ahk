#Requires AutoHotkey v2.0
; Calendar QuickAdd — global Alt+C launcher.
; Alt+C anywhere in Windows:
;   1. Makes sure the local Python server is running (starts it hidden if not).
;   2. Focuses the existing tab if open, else opens it in Chrome.
;
; Keep this .ahk file in the same folder as index.html — the server is started
; with that folder as its working directory, so it serves the right files.

Port := 8000
URL := "http://localhost:" Port
ServerDir := A_ScriptDir   ; folder this script lives in (= the Calendar folder)

!c:: {
    EnsureServer()
    if WinExist("Calendar QuickAdd") {
        WinActivate
    } else {
        try
            Run('firefox.exe "' URL '"')
        catch
            Run(URL)   ; fall back to the default browser
    }
}

; Returns true if something answers on http://localhost:<Port>/.
ServerRunning() {
    global Port
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.SetTimeouts(1000, 1000, 1000, 1000)   ; don't hang if nothing's there
        req.Open("GET", "http://localhost:" Port "/", false)
        req.Send()
        return true
    } catch {
        return false
    }
}

; Starts the Python server (hidden) if it isn't already running, then waits for it.
EnsureServer() {
    global Port, ServerDir
    if ServerRunning()
        return
    try {
        ; Working-directory arg makes http.server serve ServerDir's files.
        Run('python -m http.server ' Port, ServerDir, "Hide")
    } catch {
        MsgBox("Couldn't start the server. Is Python on your PATH?", "Calendar QuickAdd", "Icon!")
        return
    }
    Loop 25 {              ; wait up to ~5s for it to come up
        if ServerRunning()
            return
        Sleep 200
    }
}
