#Requires AutoHotkey v2.0
#SingleInstance Force

; Eyes Guardian - tiny draggable eye reminder for Windows 11.

global APP_NAME := "EyesGuardian"
global CYCLE_SECONDS := 1200
global WIN_W := 118
global WIN_H := 88
global TRANS_COLOR := "FF00FF"

global EYE_LEFT := 8
global EYE_TOP := 12
global EYE_RIGHT := 80
global EYE_BOTTOM := 72
global IRIS_LEFT := 32
global IRIS_TOP := 28
global IRIS_RIGHT := 56
global IRIS_BOTTOM := 52
global PUPIL_LEFT := 39
global PUPIL_TOP := 35
global PUPIL_RIGHT := 49
global PUPIL_BOTTOM := 45
global HIGHLIGHT_LEFT := 44
global HIGHLIGHT_TOP := 33
global HIGHLIGHT_RIGHT := 48
global HIGHLIGHT_BOTTOM := 37

global gState := Map()
gState["settingsDir"] := EnvGet("LOCALAPPDATA") "\EyesGuardian"
gState["settingsFile"] := gState["settingsDir"] "\settings.ini"
gState["cycleStart"] := A_TickCount
gState["pinned"] := true
gState["pinLabel"] := "Unpin"

Init()
return

Init() {
    global gState, WIN_W, WIN_H, TRANS_COLOR

    settings := LoadSettings()
    gState["pinned"] := settings["pinned"]
    gState["pinLabel"] := gState["pinned"] ? "Unpin" : "Pin"

    pos := ResolveStartPosition(settings["x"], settings["y"], WIN_W, WIN_H)

    mainWin := Gui("-Caption +ToolWindow +AlwaysOnTop +LastFound", "Eyes Guardian")
    mainWin.BackColor := TRANS_COLOR
    mainWin.MarginX := 0
    mainWin.MarginY := 0

    mainWin.SetFont("s30 Bold cFF7A3D", "Segoe UI")
    alertCtrl := mainWin.AddText("x86 y14 w22 h58 +0x200 BackgroundTrans Hidden", "!")

    mainWin.Show("x" pos["x"] " y" pos["y"] " w" WIN_W " h" WIN_H)
    WinSetTransColor(TRANS_COLOR, "ahk_id " mainWin.Hwnd)
    ApplyPinned(mainWin.Hwnd, gState["pinned"])

    contextMenu := Menu()
    contextMenu.Add(gState["pinLabel"], TogglePinned)
    contextMenu.Add("Close", CloseFromMenu)

    gState["gui"] := mainWin
    gState["menu"] := contextMenu
    gState["alertCtrl"] := alertCtrl

    mainWin.OnEvent("Close", (*) => ExitApp())
    mainWin.OnEvent("Escape", (*) => ExitApp())

    OnMessage(0x000F, WM_PAINT)         ; WM_PAINT
    OnMessage(0x0201, WM_LBUTTONDOWN)   ; WM_LBUTTONDOWN
    OnMessage(0x0203, WM_LBUTTONDBLCLK) ; WM_LBUTTONDBLCLK
    OnMessage(0x0205, WM_RBUTTONUP)     ; WM_RBUTTONUP
    OnMessage(0x0232, WM_EXITSIZEMOVE)  ; WM_EXITSIZEMOVE
    OnExit(SaveOnExit)

    SetTimer(UpdateVisualState, 1000)
    UpdateVisualState()
}

LoadSettings() {
    global gState
    file := gState["settingsFile"]

    x := ""
    y := ""
    pinned := true

    if FileExist(file) {
        x := ParseIntOrBlank(IniRead(file, "window", "x", ""))
        y := ParseIntOrBlank(IniRead(file, "window", "y", ""))
        pinnedVal := IniRead(file, "state", "pinned", "1")
        pinned := pinnedVal != "0"
    }

    return Map("x", x, "y", y, "pinned", pinned)
}

ResolveStartPosition(x, y, width, height) {
    ; Virtual screen metrics keep placement safe on multi-monitor setups.
    vx := DllCall("GetSystemMetrics", "int", 76, "int")
    vy := DllCall("GetSystemMetrics", "int", 77, "int")
    vw := DllCall("GetSystemMetrics", "int", 78, "int")
    vh := DllCall("GetSystemMetrics", "int", 79, "int")

    minX := vx
    minY := vy
    maxX := vx + vw - width
    maxY := vy + vh - height

    if (x = "" || y = "") {
        return Map(
            "x", vx + (vw - width) // 2,
            "y", vy + (vh - height) // 2
        )
    }

    safeX := Min(Max(x, minX), maxX)
    safeY := Min(Max(y, minY), maxY)
    return Map("x", safeX, "y", safeY)
}

ParseIntOrBlank(value) {
    try {
        return Integer(value)
    } catch {
        return ""
    }
}

TogglePinned(*) {
    global gState
    gui := gState["gui"]
    menu := gState["menu"]

    oldLabel := gState["pinLabel"]
    gState["pinned"] := !gState["pinned"]
    gState["pinLabel"] := gState["pinned"] ? "Unpin" : "Pin"

    menu.Rename(oldLabel, gState["pinLabel"])
    ApplyPinned(gui.Hwnd, gState["pinned"])
    SaveSettings()
}

ApplyPinned(hwnd, isPinned) {
    WinSetAlwaysOnTop(isPinned ? 1 : 0, "ahk_id " hwnd)
}

CloseFromMenu(*) {
    ExitApp()
}

ResetCycle() {
    global gState
    gState["cycleStart"] := A_TickCount
    gState["alertCtrl"].Opt("+Hidden")
    InvalidateWindow(gState["gui"].Hwnd)
}

UpdateVisualState() {
    global gState, CYCLE_SECONDS
    elapsedMs := A_TickCount - gState["cycleStart"]
    isDue := elapsedMs >= (CYCLE_SECONDS * 1000)

    if isDue {
        gState["alertCtrl"].Opt("-Hidden")
    } else {
        gState["alertCtrl"].Opt("+Hidden")
    }

    InvalidateWindow(gState["gui"].Hwnd)
}

SaveSettings() {
    global gState
    gui := gState["gui"]
    file := gState["settingsFile"]
    dir := gState["settingsDir"]

    if !DirExist(dir) {
        DirCreate(dir)
    }

    WinGetPos(&x, &y, , , "ahk_id " gui.Hwnd)
    IniWrite(x, file, "window", "x")
    IniWrite(y, file, "window", "y")
    IniWrite(gState["pinned"] ? "1" : "0", file, "state", "pinned")
}

SaveOnExit(exitReason, exitCode) {
    SaveSettings()
}

WM_EXITSIZEMOVE(wParam, lParam, msg, hwnd) {
    global gState
    if hwnd = gState["gui"].Hwnd {
        SaveSettings()
    }
}

WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global gState
    target := ResolveTopLevelTarget(hwnd)
    if target != gState["gui"].Hwnd {
        return
    }
    PostMessage(0x00A1, 2, 0, , "ahk_id " target) ; WM_NCLBUTTONDOWN + HTCAPTION
}

WM_LBUTTONDBLCLK(wParam, lParam, msg, hwnd) {
    global gState
    target := ResolveTopLevelTarget(hwnd)
    if target != gState["gui"].Hwnd {
        return
    }
    ResetCycle()
    return 0
}

WM_RBUTTONUP(wParam, lParam, msg, hwnd) {
    global gState
    target := ResolveTopLevelTarget(hwnd)
    if target != gState["gui"].Hwnd {
        return
    }
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    gState["menu"].Show(mx, my)
    return 0
}

ResolveTopLevelTarget(hwnd) {
    root := DllCall("GetAncestor", "ptr", hwnd, "uint", 2, "ptr") ; GA_ROOT = 2
    return root ? root : hwnd
}

WM_PAINT(wParam, lParam, msg, hwnd) {
    global gState
    if !gState.Has("gui") {
        return
    }
    if hwnd != gState["gui"].Hwnd {
        return
    }

    psSize := (A_PtrSize = 8) ? 72 : 64
    ps := Buffer(psSize, 0)
    hdc := DllCall("BeginPaint", "ptr", hwnd, "ptr", ps, "ptr")
    DrawEye(hdc)
    DllCall("EndPaint", "ptr", hwnd, "ptr", ps)
    return 0
}

DrawEye(hdc) {
    global gState
    global TRANS_COLOR
    global EYE_LEFT, EYE_TOP, EYE_RIGHT, EYE_BOTTOM
    global IRIS_LEFT, IRIS_TOP, IRIS_RIGHT, IRIS_BOTTOM
    global PUPIL_LEFT, PUPIL_TOP, PUPIL_RIGHT, PUPIL_BOTTOM
    global HIGHLIGHT_LEFT, HIGHLIGHT_TOP, HIGHLIGHT_RIGHT, HIGHLIGHT_BOTTOM
    global CYCLE_SECONDS

    elapsedMs := A_TickCount - gState["cycleStart"]
    progress := elapsedMs / (CYCLE_SECONDS * 1000.0)
    if (progress < 0) {
        progress := 0
    } else if (progress > 1) {
        progress := 1
    }

    ; Soft white -> warm red tint over 20 minutes.
    scleraR := 255
    scleraG := Round(255 - (95 * progress))
    scleraB := Round(255 - (105 * progress))

    bgBrush := DllCall("gdi32\CreateSolidBrush", "uint", RgbToColorRefHex(TRANS_COLOR), "ptr")
    rect := Buffer(16, 0)
    DllCall("GetClientRect", "ptr", gState["gui"].Hwnd, "ptr", rect)
    DllCall("FillRect", "ptr", hdc, "ptr", rect, "ptr", bgBrush)
    DllCall("gdi32\DeleteObject", "ptr", bgBrush)

    outlinePen := DllCall("gdi32\CreatePen", "int", 0, "int", 2, "uint", RgbToColorRef(84, 84, 84), "ptr")
    oldPen := DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", outlinePen, "ptr")

    scleraBrush := DllCall("gdi32\CreateSolidBrush", "uint", RgbToColorRef(scleraR, scleraG, scleraB), "ptr")
    oldBrush := DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", scleraBrush, "ptr")
    DllCall("gdi32\Ellipse", "ptr", hdc, "int", EYE_LEFT, "int", EYE_TOP, "int", EYE_RIGHT, "int", EYE_BOTTOM)

    irisBrush := DllCall("gdi32\CreateSolidBrush", "uint", RgbToColorRef(66, 163, 204), "ptr")
    DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", irisBrush, "ptr")
    DllCall("gdi32\Ellipse", "ptr", hdc, "int", IRIS_LEFT, "int", IRIS_TOP, "int", IRIS_RIGHT, "int", IRIS_BOTTOM)

    pupilBrush := DllCall("gdi32\CreateSolidBrush", "uint", RgbToColorRef(24, 24, 24), "ptr")
    DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", pupilBrush, "ptr")
    DllCall("gdi32\Ellipse", "ptr", hdc, "int", PUPIL_LEFT, "int", PUPIL_TOP, "int", PUPIL_RIGHT, "int", PUPIL_BOTTOM)

    highlightBrush := DllCall("gdi32\CreateSolidBrush", "uint", RgbToColorRef(255, 255, 255), "ptr")
    DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", highlightBrush, "ptr")
    DllCall("gdi32\Ellipse", "ptr", hdc, "int", HIGHLIGHT_LEFT, "int", HIGHLIGHT_TOP, "int", HIGHLIGHT_RIGHT, "int", HIGHLIGHT_BOTTOM)

    ; Small eyelash accents to make the eye look friendlier.
    lashPen := DllCall("gdi32\CreatePen", "int", 0, "int", 2, "uint", RgbToColorRef(94, 94, 94), "ptr")
    DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", lashPen, "ptr")
    DllCall("gdi32\MoveToEx", "ptr", hdc, "int", 23, "int", 14, "ptr", 0)
    DllCall("gdi32\LineTo", "ptr", hdc, "int", 18, "int", 8)
    DllCall("gdi32\MoveToEx", "ptr", hdc, "int", 44, "int", 11, "ptr", 0)
    DllCall("gdi32\LineTo", "ptr", hdc, "int", 44, "int", 5)
    DllCall("gdi32\MoveToEx", "ptr", hdc, "int", 65, "int", 14, "ptr", 0)
    DllCall("gdi32\LineTo", "ptr", hdc, "int", 70, "int", 8)

    DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", oldBrush, "ptr")
    DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", oldPen, "ptr")

    DllCall("gdi32\DeleteObject", "ptr", scleraBrush)
    DllCall("gdi32\DeleteObject", "ptr", irisBrush)
    DllCall("gdi32\DeleteObject", "ptr", pupilBrush)
    DllCall("gdi32\DeleteObject", "ptr", highlightBrush)
    DllCall("gdi32\DeleteObject", "ptr", lashPen)
    DllCall("gdi32\DeleteObject", "ptr", outlinePen)
}

InvalidateWindow(hwnd) {
    DllCall("InvalidateRect", "ptr", hwnd, "ptr", 0, "int", 1)
}

RgbToColorRef(r, g, b) {
    return (b << 16) | (g << 8) | r
}

RgbToColorRefHex(hexRgb) {
    value := Integer("0x" hexRgb)
    r := (value >> 16) & 0xFF
    g := (value >> 8) & 0xFF
    b := value & 0xFF
    return RgbToColorRef(r, g, b)
}
