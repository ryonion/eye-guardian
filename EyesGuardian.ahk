#Requires AutoHotkey v2.0
#SingleInstance Force

; Eyes Guardian - tiny draggable eye reminder for Windows 11.

global APP_NAME := "EyesGuardian"
global CYCLE_SECONDS := 1200
global WIN_W := 118
global WIN_H := 88
global TRANS_COLOR := "FF00FF"
global TOOLTIP_ID := 19

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
gState["resetCount"] := 0
gState["hoveringEye"] := false
gState["trackMouse"] := false
gState["hoverScreenX"] := 0
gState["hoverScreenY"] := 0
gState["tooltipVisible"] := false
gState["tooltipText"] := ""
gState["sparkActive"] := false
gState["sparkStartTick"] := 0
gState["sparkDurationMs"] := 700
gState["vessels"] := BuildVesselSegments()
gState["sparks"] := BuildSparkRays()

Init()
return

Init() {
    global gState, WIN_W, WIN_H, TRANS_COLOR

    ; Keep all overlay coordinates in screen space across callbacks.
    CoordMode("Mouse", "Screen")
    CoordMode("Menu", "Screen")
    CoordMode("ToolTip", "Screen")

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
    OnMessage(0x0200, WM_MOUSEMOVE)     ; WM_MOUSEMOVE
    OnMessage(0x0201, WM_LBUTTONDOWN)   ; WM_LBUTTONDOWN
    OnMessage(0x0203, WM_LBUTTONDBLCLK) ; WM_LBUTTONDBLCLK
    OnMessage(0x0205, WM_RBUTTONUP)     ; WM_RBUTTONUP
    OnMessage(0x02A3, WM_MOUSELEAVE)    ; WM_MOUSELEAVE
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

BuildVesselSegments() {
    return [
        Map("x1", 14, "y1", 38, "x2", 24, "y2", 34),
        Map("x1", 15, "y1", 45, "x2", 26, "y2", 42),
        Map("x1", 20, "y1", 52, "x2", 30, "y2", 49),
        Map("x1", 65, "y1", 31, "x2", 55, "y2", 29),
        Map("x1", 68, "y1", 39, "x2", 58, "y2", 36),
        Map("x1", 66, "y1", 49, "x2", 56, "y2", 45),
        Map("x1", 30, "y1", 22, "x2", 35, "y2", 27),
        Map("x1", 41, "y1", 21, "x2", 43, "y2", 27),
        Map("x1", 53, "y1", 23, "x2", 49, "y2", 28),
        Map("x1", 28, "y1", 61, "x2", 33, "y2", 55),
        Map("x1", 41, "y1", 63, "x2", 42, "y2", 56),
        Map("x1", 55, "y1", 60, "x2", 50, "y2", 54)
    ]
}

BuildSparkRays() {
    return [
        Map("angle", -10, "start", 4, "end", 13, "width", 2, "phase", 0.0),
        Map("angle", 18, "start", 3, "end", 12, "width", 1, "phase", 0.8),
        Map("angle", 48, "start", 4, "end", 14, "width", 2, "phase", 1.3),
        Map("angle", 78, "start", 3, "end", 11, "width", 1, "phase", 2.1),
        Map("angle", 110, "start", 4, "end", 13, "width", 2, "phase", 2.7),
        Map("angle", 145, "start", 3, "end", 12, "width", 1, "phase", 3.4),
        Map("angle", 178, "start", 4, "end", 14, "width", 2, "phase", 4.0),
        Map("angle", 212, "start", 3, "end", 11, "width", 1, "phase", 4.7),
        Map("angle", 246, "start", 4, "end", 13, "width", 2, "phase", 5.2),
        Map("angle", 280, "start", 3, "end", 12, "width", 1, "phase", 5.8),
        Map("angle", 316, "start", 4, "end", 14, "width", 2, "phase", 0.6),
        Map("angle", 344, "start", 3, "end", 11, "width", 1, "phase", 1.8)
    ]
}

GetCycleState() {
    global gState, CYCLE_SECONDS
    elapsedMs := Max(0, A_TickCount - gState["cycleStart"])
    progress := elapsedMs / (CYCLE_SECONDS * 1000.0)
    progress := Clamp(progress, 0.0, 1.0)
    return Map(
        "elapsedMs", elapsedMs,
        "progress", progress,
        "isDue", elapsedMs >= (CYCLE_SECONDS * 1000)
    )
}

FormatElapsedTooltip(elapsedMs) {
    global gState
    return Floor(elapsedMs / 60000) " min elapsed | " gState["resetCount"] " rests this launch"
}

ShowElapsedTooltip(elapsedMs) {
    global gState, TOOLTIP_ID
    text := FormatElapsedTooltip(elapsedMs)
    anchor := ResolveTooltipAnchor(gState["gui"].Hwnd)
    tipX := anchor["x"]
    tipY := anchor["y"]
    ToolTip(text, tipX, tipY, TOOLTIP_ID)
    gState["tooltipText"] := text
    gState["tooltipVisible"] := true
}

HideElapsedTooltip() {
    global gState, TOOLTIP_ID
    ToolTip(, , , TOOLTIP_ID)
    gState["tooltipText"] := ""
    gState["tooltipVisible"] := false
}

UpdateHoverTooltip(elapsedMs := -1) {
    global gState
    if !gState["hoveringEye"] {
        return
    }

    if elapsedMs < 0 {
        elapsedMs := GetCycleState()["elapsedMs"]
    }

    text := FormatElapsedTooltip(elapsedMs)
    if !gState["tooltipVisible"] || (text != gState["tooltipText"]) {
        ShowElapsedTooltip(elapsedMs)
    }
}

TrackMouseLeaveForWindow(hwnd) {
    global gState
    if gState["trackMouse"] {
        return
    }

    tmeSize := (A_PtrSize = 8) ? 24 : 16
    tme := Buffer(tmeSize, 0)
    NumPut("UInt", tmeSize, tme, 0)
    NumPut("UInt", 0x00000002, tme, 4) ; TME_LEAVE
    NumPut("Ptr", hwnd, tme, 8)
    NumPut("UInt", 0, tme, 8 + A_PtrSize)
    DllCall("TrackMouseEvent", "ptr", tme)
    gState["trackMouse"] := true
}

ActivateSparkBurst() {
    global gState
    gState["sparkActive"] := true
    gState["sparkStartTick"] := A_TickCount
    SetTimer(SparkTick, 33)
}

SparkTick() {
    global gState
    if !gState["sparkActive"] {
        SetTimer(SparkTick, 0)
        return
    }

    if (A_TickCount - gState["sparkStartTick"]) >= gState["sparkDurationMs"] {
        gState["sparkActive"] := false
        SetTimer(SparkTick, 0)
    }

    InvalidateWindow(gState["gui"].Hwnd)
}

IsPointInEye(clientX, clientY) {
    global EYE_LEFT, EYE_TOP, EYE_RIGHT, EYE_BOTTOM
    cx := (EYE_LEFT + EYE_RIGHT) / 2.0
    cy := (EYE_TOP + EYE_BOTTOM) / 2.0
    rx := (EYE_RIGHT - EYE_LEFT) / 2.0
    ry := (EYE_BOTTOM - EYE_TOP) / 2.0
    if (rx <= 0 || ry <= 0) {
        return false
    }

    dx := (clientX - cx) / rx
    dy := (clientY - cy) / ry
    return (dx * dx + dy * dy) <= 1.0
}

ResolveContextMenuAnchor(hwnd) {
    global EYE_LEFT, EYE_TOP, EYE_RIGHT, EYE_BOTTOM
    WinGetPos(&winX, &winY, , , "ahk_id " hwnd)

    eyeCenterY := winY + Round((EYE_TOP + EYE_BOTTOM) / 2.0)
    rightAnchorX := winX + EYE_RIGHT + 4
    leftAnchorX := winX + EYE_LEFT - 4

    vx := DllCall("GetSystemMetrics", "int", 76, "int")
    vy := DllCall("GetSystemMetrics", "int", 77, "int")
    vw := DllCall("GetSystemMetrics", "int", 78, "int")
    vh := DllCall("GetSystemMetrics", "int", 79, "int")

    maxX := vx + vw
    maxY := vy + vh
    edgePad := 4
    estMenuW := 128
    estMenuH := 72

    if (rightAnchorX + estMenuW) <= (maxX - edgePad) {
        menuX := rightAnchorX
    } else {
        menuX := leftAnchorX - estMenuW
    }

    menuY := eyeCenterY - (estMenuH // 2)
    menuX := Clamp(menuX, vx + edgePad, maxX - estMenuW - edgePad)
    menuY := Clamp(menuY, vy + edgePad, maxY - estMenuH - edgePad)
    return Map("x", menuX, "y", menuY)
}

ResolveTooltipAnchor(hwnd) {
    global EYE_LEFT, EYE_TOP, EYE_RIGHT
    WinGetPos(&winX, &winY, , , "ahk_id " hwnd)

    ; Prefer tooltip just above-right of the eye.
    tipX := winX + EYE_RIGHT + 4
    tipY := winY + EYE_TOP - 22

    vx := DllCall("GetSystemMetrics", "int", 76, "int")
    vy := DllCall("GetSystemMetrics", "int", 77, "int")
    vw := DllCall("GetSystemMetrics", "int", 78, "int")
    vh := DllCall("GetSystemMetrics", "int", 79, "int")

    maxX := vx + vw
    maxY := vy + vh
    edgePad := 4
    estTipW := 220
    estTipH := 24

    tipX := Clamp(tipX, vx + edgePad, maxX - estTipW - edgePad)
    tipY := Clamp(tipY, vy + edgePad, maxY - estTipH - edgePad)
    return Map("x", tipX, "y", tipY)
}

TogglePinned(*) {
    global gState
    mainWin := gState["gui"]
    contextMenu := gState["menu"]

    oldLabel := gState["pinLabel"]
    gState["pinned"] := !gState["pinned"]
    gState["pinLabel"] := gState["pinned"] ? "Unpin" : "Pin"

    contextMenu.Rename(oldLabel, gState["pinLabel"])
    ApplyPinned(mainWin.Hwnd, gState["pinned"])
    SaveSettings()
}

ApplyPinned(hwnd, isPinned) {
    WinSetAlwaysOnTop(isPinned ? 1 : 0, "ahk_id " hwnd)
}

CloseFromMenu(*) {
    HideElapsedTooltip()
    ExitApp()
}

ResetCycle() {
    global gState
    gState["cycleStart"] := A_TickCount
    gState["resetCount"] := gState["resetCount"] + 1
    gState["alertCtrl"].Opt("+Hidden")
    ActivateSparkBurst()
    if gState["hoveringEye"] {
        UpdateHoverTooltip(0)
    }
    InvalidateWindow(gState["gui"].Hwnd)
}

UpdateVisualState() {
    global gState
    cycle := GetCycleState()

    if cycle["isDue"] {
        gState["alertCtrl"].Opt("-Hidden")
    } else {
        gState["alertCtrl"].Opt("+Hidden")
    }

    if gState["hoveringEye"] {
        UpdateHoverTooltip(cycle["elapsedMs"])
    }

    InvalidateWindow(gState["gui"].Hwnd)
}

SaveSettings() {
    global gState
    mainWin := gState["gui"]
    file := gState["settingsFile"]
    dir := gState["settingsDir"]

    if !DirExist(dir) {
        DirCreate(dir)
    }

    WinGetPos(&x, &y, , , "ahk_id " mainWin.Hwnd)
    IniWrite(x, file, "window", "x")
    IniWrite(y, file, "window", "y")
    IniWrite(gState["pinned"] ? "1" : "0", file, "state", "pinned")
}

SaveOnExit(exitReason, exitCode) {
    HideElapsedTooltip()
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
    gState["hoveringEye"] := false
    gState["trackMouse"] := false
    HideElapsedTooltip()
    anchor := ResolveContextMenuAnchor(target)
    gState["menu"].Show(anchor["x"], anchor["y"])
    return 0
}

WM_MOUSEMOVE(wParam, lParam, msg, hwnd) {
    global gState
    target := ResolveTopLevelTarget(hwnd)
    if target != gState["gui"].Hwnd {
        return
    }

    TrackMouseLeaveForWindow(target)
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    gState["hoverScreenX"] := mx
    gState["hoverScreenY"] := my

    WinGetPos(&winX, &winY, , , "ahk_id " target)
    clientX := mx - winX
    clientY := my - winY
    isInside := IsPointInEye(clientX, clientY)

    if isInside {
        gState["hoveringEye"] := true
        UpdateHoverTooltip()
    } else if gState["hoveringEye"] {
        gState["hoveringEye"] := false
        HideElapsedTooltip()
    }
    return 0
}

WM_MOUSELEAVE(wParam, lParam, msg, hwnd) {
    global gState
    target := ResolveTopLevelTarget(hwnd)
    if target != gState["gui"].Hwnd {
        return
    }
    gState["trackMouse"] := false
    gState["hoveringEye"] := false
    HideElapsedTooltip()
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
    cycle := GetCycleState()
    progress := cycle["progress"]

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
    DrawBloodVessels(hdc, progress)

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

    DrawSparkBurst(hdc)

    DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", oldBrush, "ptr")
    DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", oldPen, "ptr")

    DllCall("gdi32\DeleteObject", "ptr", scleraBrush)
    DllCall("gdi32\DeleteObject", "ptr", irisBrush)
    DllCall("gdi32\DeleteObject", "ptr", pupilBrush)
    DllCall("gdi32\DeleteObject", "ptr", highlightBrush)
    DllCall("gdi32\DeleteObject", "ptr", lashPen)
    DllCall("gdi32\DeleteObject", "ptr", outlinePen)
}

DrawBloodVessels(hdc, progress) {
    global gState
    segments := gState["vessels"]
    if (progress < 0.1) || (segments.Length = 0) {
        return
    }

    intensity := Clamp((progress - 0.1) / 0.9, 0.0, 1.0)
    visibleCount := Round(2 + (segments.Length - 2) * intensity)
    visibleCount := Min(Max(visibleCount, 0), segments.Length)

    vesselR := Round(215 + 25 * intensity)
    vesselG := Round(170 - 55 * intensity)
    vesselB := Round(178 - 68 * intensity)

    vesselPen := DllCall("gdi32\CreatePen", "int", 0, "int", 1, "uint", RgbToColorRef(vesselR, vesselG, vesselB), "ptr")
    oldPen := DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", vesselPen, "ptr")

    loop visibleCount {
        seg := segments[A_Index]
        DllCall("gdi32\MoveToEx", "ptr", hdc, "int", seg["x1"], "int", seg["y1"], "ptr", 0)
        DllCall("gdi32\LineTo", "ptr", hdc, "int", seg["x2"], "int", seg["y2"])
    }

    DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", oldPen, "ptr")
    DllCall("gdi32\DeleteObject", "ptr", vesselPen)
}

DrawSparkBurst(hdc) {
    global gState
    global EYE_LEFT, EYE_TOP, EYE_RIGHT, EYE_BOTTOM
    if !gState["sparkActive"] {
        return
    }

    elapsed := A_TickCount - gState["sparkStartTick"]
    duration := gState["sparkDurationMs"]
    if duration <= 0 {
        return
    }

    t := Clamp(elapsed / duration, 0.0, 1.0)
    fade := 1.0 - t

    cx := (EYE_LEFT + EYE_RIGHT) / 2.0
    cy := (EYE_TOP + EYE_BOTTOM) / 2.0
    baseRadius := Max((EYE_RIGHT - EYE_LEFT) / 2.0, (EYE_BOTTOM - EYE_TOP) / 2.0) + 2

    for ray in gState["sparks"] {
        pulse := 0.45 + 0.55 * Abs(Sin((t * 6.283185) + ray["phase"]))
        strength := fade * pulse
        if strength < 0.08 {
            continue
        }

        startDist := baseRadius + ray["start"]
        endDist := baseRadius + ray["end"]
        x1 := Round(cx + CosDeg(ray["angle"]) * startDist)
        y1 := Round(cy + SinDeg(ray["angle"]) * startDist)
        x2 := Round(cx + CosDeg(ray["angle"]) * endDist)
        y2 := Round(cy + SinDeg(ray["angle"]) * endDist)

        sparkR := 255
        sparkG := Round(214 + 40 * strength)
        sparkB := Round(140 + 80 * strength)
        sparkPen := DllCall("gdi32\CreatePen", "int", 0, "int", ray["width"], "uint", RgbToColorRef(sparkR, sparkG, sparkB), "ptr")
        oldPen := DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", sparkPen, "ptr")
        DllCall("gdi32\MoveToEx", "ptr", hdc, "int", x1, "int", y1, "ptr", 0)
        DllCall("gdi32\LineTo", "ptr", hdc, "int", x2, "int", y2)
        DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", oldPen, "ptr")
        DllCall("gdi32\DeleteObject", "ptr", sparkPen)
    }
}

InvalidateWindow(hwnd) {
    DllCall("InvalidateRect", "ptr", hwnd, "ptr", 0, "int", 1)
}

Clamp(value, low, high) {
    if value < low {
        return low
    }
    if value > high {
        return high
    }
    return value
}

CosDeg(degrees) {
    return Cos(degrees * 0.01745329252)
}

SinDeg(degrees) {
    return Sin(degrees * 0.01745329252)
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
