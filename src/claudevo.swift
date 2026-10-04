// claudevo: VoiceOver jump keys and spoken information for the Claude desktop app on macOS.
//
// Commands
//   prompt     move keyboard focus to the message box
//   sidebar    move focus to the open session in the sidebar
//   mode       move focus to the Chat and Cowork / Code buttons
//   routines   move focus to Routines
//   speak      print or announce Claude's latest reply
//   waiting    print or announce which sessions are running or waiting for you
//   info       print or announce model, effort, permission mode and usage
//   session    print or announce the open session and its folder
//   record     press the dictation button (or the stop button while recording)
//   recordstate  print "stop" if dictation is running, otherwise "start"
//   say TEXT   announce TEXT
// Add --print to print text instead of announcing it (the VoiceOver scripts use this and speak it themselves).
//
// Uses the macOS accessibility API only: no synthetic keystrokes, nothing is opened.
// It finds controls by their accessibility labels, so a Claude app update that renames a control can break a key.
import Cocoa
import ApplicationServices

let launched = Date()
let args = CommandLine.arguments
let cmd = args.dropFirst().first ?? ""
let printMode = args.contains("--print")

func attr(_ e: AXUIElement, _ a: String) -> AnyObject? { var v: AnyObject?; AXUIElementCopyAttributeValue(e, a as CFString, &v); return v }
func str(_ e: AXUIElement, _ a: String) -> String { (attr(e, a) as? String) ?? "" }
func kids(_ e: AXUIElement) -> [AXUIElement] { (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] }
func classes(_ e: AXUIElement) -> [String] { (attr(e, "AXDOMClassList") as? [String]) ?? [] }

func announce(_ text: String) {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    NSAccessibility.post(element: app as Any, notification: .announcementRequested,
                         userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    RunLoop.current.run(until: Date().addingTimeInterval(1.0))
}
func emit(_ t: String) { if printMode { print(t) } else { announce(t) } }

if cmd.isEmpty || cmd == "help" {
    print("usage: claudevo prompt|sidebar|mode|routines|speak|waiting|info|session|record|recordstate|say TEXT [--print]")
    exit(0)
}
if cmd == "say" { announce(args.dropFirst(2).filter { $0 != "--print" }.joined(separator: " ")); exit(0) }

if !AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary) {
    emit("Claude VoiceOver keys need Accessibility permission. In System Settings, Privacy and Security, Accessibility, switch on claudevo.")
    exit(2)
}
guard let claude = NSRunningApplication.runningApplications(withBundleIdentifier: "com.anthropic.claudefordesktop").first else {
    emit("Claude is not running"); exit(1)
}
let appEl = AXUIElementCreateApplication(claude.processIdentifier)
let windows = (attr(appEl, kAXWindowsAttribute) as? [AXUIElement]) ?? []
let focusedWin = attr(appEl, kAXFocusedWindowAttribute).map { $0 as! AXUIElement }
guard let mainWin = focusedWin ?? windows.first else { emit("No Claude window found"); exit(1) }

// The whole window, flattened in reading order.
var flat: [AXUIElement] = []
func walk(_ e: AXUIElement, _ d: Int) { flat.append(e); if d < 60 { for c in kids(e) { walk(c, d + 1) } } }
walk(mainWin, 0)

func focus(_ e: AXUIElement) -> Bool {
    claude.activate()
    return AXUIElementSetAttributeValue(e, kAXFocusedAttribute as CFString, kCFBooleanTrue) == .success
}
func insideButton(_ e: AXUIElement) -> Bool {
    var cur = e
    for _ in 0..<4 {
        guard let p = attr(cur, kAXParentAttribute) else { return false }
        let pe = p as! AXUIElement
        if ["AXButton", "AXDisclosureTriangle"].contains(str(pe, kAXRoleAttribute)) { return true }
        cur = pe
    }
    return false
}

let promptIdx = flat.firstIndex { str($0, kAXRoleAttribute) == "AXTextArea" && str($0, kAXDescriptionAttribute) == "Prompt" }
let pageTitle = flat.map { str($0, kAXTitleAttribute) }.first { $0.hasSuffix(" - Claude Code") || $0.hasSuffix(" - Claude") } ?? ""
let currentSession = pageTitle.replacingOccurrences(of: " - Claude Code", with: "").replacingOccurrences(of: " - Claude", with: "")
// Sidebar rows are buttons titled "<status> <session name>".
let sessionButtons = flat.filter { str($0, kAXRoleAttribute) == "AXButton" && classes($0).contains("w-full")
    && !["New", "Projects Beta", "Artifacts", "Routines", "Customize", "Pinned"].contains(str($0, kAXTitleAttribute)) }
// Controls belonging to the message box: everything after the Prompt box, never the conversation.
let composerControls = promptIdx.map { Array(flat[$0...]) } ?? []
func isStopDictation(_ e: AXUIElement) -> Bool {
    guard ["AXCheckBox", "AXButton"].contains(str(e, kAXRoleAttribute)) else { return false }
    let d = str(e, kAXDescriptionAttribute).lowercased()
    return d.contains("stop") && (d.contains("dictat") || d.contains("record"))
}

switch cmd {
case "prompt":
    if let i = promptIdx, focus(flat[i]) { } else { emit("Message box not found") }

case "sidebar":
    let target = sessionButtons.first { !currentSession.isEmpty && str($0, kAXTitleAttribute).hasSuffix(currentSession) } ?? sessionButtons.first
    if let r = target, focus(r) { } else { emit("Sidebar not found") }

case "mode":
    let radios = flat.filter { str($0, kAXRoleAttribute) == "AXRadioButton" && ["Chat and Cowork", "Code"].contains(str($0, kAXDescriptionAttribute)) }
    let on = radios.first { (attr($0, kAXValueAttribute) as? Int) == 1 } ?? radios.first
    if let r = on, focus(r) { } else { emit("Mode buttons not found") }

case "routines":
    if let r = flat.first(where: { str($0, kAXRoleAttribute) == "AXButton" && str($0, kAXTitleAttribute) == "Routines" }), focus(r) { } else { emit("Routines not found") }

case "speak":
    guard let i = flat.lastIndex(where: { str($0, kAXRoleAttribute) == "AXHeading" && str($0, kAXTitleAttribute).hasPrefix("Claude responded") }) else { emit("No reply found"); break }
    var parts: [String] = []
    for e in flat[(i + 1)...] {
        let role = str(e, kAXRoleAttribute)
        if role == "AXHeading" && str(e, kAXTitleAttribute).hasPrefix("You said") { break }
        if role == "AXTextArea" && str(e, kAXDescriptionAttribute) == "Prompt" { break }
        if role == "AXStaticText" && !insideButton(e) {
            let v = str(e, kAXValueAttribute).trimmingCharacters(in: .whitespacesAndNewlines)
            if !v.isEmpty && !v.hasPrefix("Claude responded") { parts.append(v) }
        }
    }
    emit(parts.isEmpty ? "The reply is empty" : parts.joined(separator: " "))

case "waiting":
    // Every session in the sidebar, grouped by status: waiting for you, running, any other status
    // (such as "Something went wrong"), then idle. The status is the description of the row's first child.
    var order: [String] = ["Awaiting input", "Running"]
    var groups: [String: [String]] = [:]
    for b in sessionButtons {
        let t = str(b, kAXTitleAttribute)
        guard let first = kids(b).first else { continue }
        let st = str(first, kAXDescriptionAttribute)
        guard !st.isEmpty, t.hasPrefix(st + " ") else { continue }
        let name = String(t.dropFirst(st.count + 1))
        if name == "Routines" { continue }
        if !order.contains(st) && st != "Idle" { order.append(st) }
        groups[st, default: []].append(name + (name == currentSession ? " (this one)" : ""))
    }
    order.append("Idle")
    let labels = ["Awaiting input": "Waiting for you"]
    let parts = order.compactMap { st in groups[st].map { "\(labels[st] ?? st): \($0.joined(separator: ", "))" } }
    emit(parts.isEmpty ? "No sessions found" : parts.joined(separator: ". "))

case "info":
    func pop(_ prefix: String) -> String? {
        flat.first { str($0, kAXRoleAttribute) == "AXPopUpButton" && str($0, kAXDescriptionAttribute).hasPrefix(prefix) }.map { str($0, kAXDescriptionAttribute) }
    }
    let modeNames = ["Auto", "Ask", "Plan", "Accept edits", "Bypass"]
    let mode = composerControls.first { el in str(el, kAXRoleAttribute) == "AXPopUpButton" && modeNames.contains { m in str(el, kAXTitleAttribute).hasPrefix(m) } }
        .map { "Permissions " + str($0, kAXTitleAttribute) }
    let parts = [pop("Model:"), pop("Effort:"), mode, pop("Usage:")].compactMap { $0 }
    emit(parts.isEmpty ? "Session details not found" : parts.joined(separator: ". "))

case "session":
    // The folder pop-up sits in the pane toolbar: a titled pop-up with no description, not the account menu.
    let folder = flat.first { str($0, kAXRoleAttribute) == "AXPopUpButton" && str($0, kAXDescriptionAttribute).isEmpty
        && !str($0, kAXTitleAttribute).isEmpty && !classes($0).contains("df-user-menu-btn") && !composerControls.contains($0) }
    emit(currentSession.isEmpty ? "Session name not found" : "You're in \(currentSession)" + (folder.map { ", folder \(str($0, kAXTitleAttribute))" } ?? ""))

case "recordstate":
    print(composerControls.contains(where: isStopDictation) ? "stop" : "start")

case "record":
    // Idle: a toggle labelled "Press and hold to record". While recording it is replaced by a stop button.
    let stop = composerControls.first(where: isStopDictation)
    let start = composerControls.first { str($0, kAXRoleAttribute) == "AXCheckBox" && str($0, kAXDescriptionAttribute) == "Press and hold to record" }
    guard let b = stop ?? start else { emit("Record button not found"); break }
    // --at N: find the button now, press it N seconds after launch (the countdown beeps play meanwhile).
    if let i = args.firstIndex(of: "--at"), i + 1 < args.count, let at = Double(args[i + 1]) {
        let wait = at - Date().timeIntervalSince(launched)
        if wait > 0 { Thread.sleep(forTimeInterval: wait) }
    }
    claude.activate()
    AXUIElementPerformAction(b, kAXPressAction as CFString)

default:
    print("unknown command: \(cmd)")
    exit(64)
}
