// claudevo: VoiceOver jump keys and spoken information for the Claude desktop app on macOS.
//
// Commands
//   prompt     move keyboard focus to the message box
//   sidebar    move focus to the open session in the sidebar
//   mode       move focus to the Chat and Cowork / Code buttons
//   routines   move focus to Scheduled (called Routines in older app versions)
//   rail       show or hide the session rail (the details panel beside the chat) and say which; --state only reports it
//   speak      print or announce Claude's latest reply
//   waiting    print or announce which sessions are running or waiting for you
//   info       print or announce model, effort, permission mode and usage
//   session    print or announce the open session and its folder
//   record     press the dictation button (or the stop button while recording)
//   recordstate  print "stop" if dictation is running, otherwise "start"
//   say TEXT   announce TEXT
//   check      try to find what every key needs in the open Claude window and list what is missing; moves nothing
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
    print("usage: claudevo prompt|sidebar|mode|routines|rail|speak|waiting|info|session|record|recordstate|check|say TEXT [--print]")
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
// A session row in the sidebar is a full-width button with its own "More options for <name>" menu button.
// Navigation rows (New, Search, Scheduled, Plugins and so on) have no such menu, so they are left out without
// needing a list of their names, which change between app versions.
let moreOptions = Set(flat.compactMap { e -> String? in
    guard str(e, kAXRoleAttribute) == "AXPopUpButton" else { return nil }
    let d = str(e, kAXDescriptionAttribute).isEmpty ? str(e, kAXTitleAttribute) : str(e, kAXDescriptionAttribute)
    return d.hasPrefix("More options for ") ? String(d.dropFirst("More options for ".count)) : nil })
func texts(_ e: AXUIElement, _ d: Int = 0) -> [String] {
    var t: [String] = []
    if str(e, kAXRoleAttribute) == "AXStaticText" { let v = str(e, kAXValueAttribute).trimmingCharacters(in: .whitespaces); if !v.isEmpty { t.append(v) } }
    if d < 6 { for c in kids(e) { t += texts(c, d + 1) } }
    return t
}
// The session's name and status. Since app 5.x the row holds two texts, the name and then the status
// ("Running", "Unread response"); no status text means idle. Older versions put the status in a status region.
func rowInfo(_ b: AXUIElement) -> (name: String, status: String) {
    let t = texts(b), title = str(b, kAXTitleAttribute)
    if let name = t.first, moreOptions.contains(name) || t.count > 1 {
        return (name, t.count > 1 ? t.dropFirst().joined(separator: " ") : "")
    }
    if let n = moreOptions.filter({ title == $0 || title.hasPrefix($0 + " ") }).max(by: { $0.count < $1.count }) {
        return (n, String(title.dropFirst(n.count)).trimmingCharacters(in: .whitespaces))
    }
    return (title, "")
}
let sessionButtons = flat.filter { str($0, kAXRoleAttribute) == "AXButton" && classes($0).contains("w-full")
    && (moreOptions.isEmpty ? !["New", "Search", "Projects Beta", "Artifacts", "Routines", "Scheduled", "Plugins", "Customize", "Pinned"].contains(str($0, kAXTitleAttribute))
        : moreOptions.contains(rowInfo($0).name)) }
let modeRadios = flat.filter { str($0, kAXRoleAttribute) == "AXRadioButton" && ["Chat and Cowork", "Claude", "Chat", "Code"].contains(str($0, kAXDescriptionAttribute)) }
let scheduledButton = flat.first { str($0, kAXRoleAttribute) == "AXButton" && ["Scheduled", "Routines"].contains(str($0, kAXTitleAttribute)) }
let railToggle = flat.first { str($0, kAXRoleAttribute) == "AXCheckBox" && str($0, kAXDescriptionAttribute).lowercased().contains("session rail") }
func railButton(_ prefix: String) -> String? {
    flat.first { str($0, kAXRoleAttribute) == "AXButton" && str($0, kAXTitleAttribute).hasPrefix(prefix + " ") }
        .map { String(str($0, kAXTitleAttribute).dropFirst(prefix.count + 1)) }
}
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
    let target = sessionButtons.first { !currentSession.isEmpty && rowInfo($0).name == currentSession } ?? sessionButtons.first
    if let r = target, focus(r) { } else { emit("Sidebar not found") }

case "mode":
    let on = modeRadios.first { (attr($0, kAXValueAttribute) as? Int) == 1 } ?? modeRadios.first
    if let r = on, focus(r) { } else { emit("Mode buttons not found") }

case "routines":
    if let r = scheduledButton, focus(r) { } else { emit("Scheduled not found") }

case "speak":
    // Skip the message's action toolbar (its "2 hours ago" time) and hidden status regions ("Chat mode").
    func insideChrome(_ e: AXUIElement) -> Bool {
        var cur: AXUIElement? = e
        for _ in 0..<8 {
            guard let c = cur, let p = attr(c, kAXParentAttribute) else { return false }
            let pe = p as! AXUIElement
            if str(pe, kAXRoleAttribute) == "AXToolbar" || str(pe, kAXSubroleAttribute) == "AXApplicationStatus" { return true }
            cur = pe
        }
        return false
    }
    guard let i = flat.lastIndex(where: { str($0, kAXRoleAttribute) == "AXHeading" && str($0, kAXTitleAttribute).hasPrefix("Claude responded") }) else { emit("No reply found"); break }
    var parts: [String] = []
    for e in flat[(i + 1)...] {
        let role = str(e, kAXRoleAttribute)
        if role == "AXHeading" && str(e, kAXTitleAttribute).hasPrefix("You said") { break }
        if role == "AXTextArea" && str(e, kAXDescriptionAttribute) == "Prompt" { break }
        if role == "AXStaticText" && !insideButton(e) && !insideChrome(e) {
            let v = str(e, kAXValueAttribute).trimmingCharacters(in: .whitespacesAndNewlines)
            if !v.isEmpty && !v.hasPrefix("Claude responded") { parts.append(v) }
        }
    }
    emit(parts.isEmpty ? "The reply is empty" : parts.joined(separator: " "))

case "waiting":
    // Every session in the sidebar, grouped by status: waiting for you, running, any other status
    // (such as "Something went wrong"), then idle. The status is the description of the row's first child.
    var order: [String] = ["Awaiting input", "Unread response", "Running"]
    var groups: [String: [String]] = [:]
    // Since app version 2.42304 (October 2026) the row's title is just the session name and the status is
    // spoken text inside a status region in the row ("Unread response", "Running" and so on); no status means idle.
    // Older versions put the status in front of the title and in the description of the row's first child.
    func statusText(_ e: AXUIElement, _ d: Int = 0) -> String? {
        if str(e, kAXSubroleAttribute) == "AXApplicationStatus" {
            var t: [String] = []
            func collect(_ x: AXUIElement) { let v = str(x, kAXValueAttribute); if !v.isEmpty { t.append(v) }; for c in kids(x) { collect(c) } }
            collect(e)
            return t.joined(separator: " ")
        }
        if d < 6 { for c in kids(e) { if let s = statusText(c, d + 1) { return s } } }
        return nil
    }
    for b in sessionButtons {
        let t = str(b, kAXTitleAttribute)
        var st = "", name = t
        if let first = kids(b).first, case let old = str(first, kAXDescriptionAttribute), !old.isEmpty, t.hasPrefix(old + " ") {
            st = old; name = String(t.dropFirst(old.count + 1))
        } else if let s = statusText(b), !s.isEmpty {
            st = s; name = rowInfo(b).name
        } else {
            (name, st) = rowInfo(b)
        }
        if st.isEmpty { st = "Idle" }
        guard !name.isEmpty else { continue }
        if ["Routines", "Scheduled"].contains(name) { continue }
        if !order.contains(st) && st != "Idle" { order.append(st) }
        groups[st, default: []].append(name + (name == currentSession ? " (this one)" : ""))
    }
    order.append("Idle")
    let labels = ["Awaiting input": "Waiting for you", "Unread response": "New reply"]
    let parts = order.compactMap { st in groups[st].map { "\(labels[st] ?? st): \($0.joined(separator: ", "))" } }
    emit(parts.isEmpty ? "No sessions found" : parts.joined(separator: ". "))

case "info":
    func pop(_ prefix: String) -> String? {
        flat.first { str($0, kAXRoleAttribute) == "AXPopUpButton" && str($0, kAXDescriptionAttribute).hasPrefix(prefix) }.map { str($0, kAXDescriptionAttribute) }
    }
    let modeNames = ["Auto", "Ask", "Plan", "Accept edits", "Bypass"]
    let mode = composerControls.first { el in str(el, kAXRoleAttribute) == "AXPopUpButton" && modeNames.contains { m in str(el, kAXTitleAttribute).hasPrefix(m) } }
        .map { "Permissions " + str($0, kAXTitleAttribute) }
    let parts = [pop("Model:"), pop("Effort:"), mode, railButton("Context").map { "Context \($0) used" }, pop("Usage:")].compactMap { $0 }
    emit(parts.isEmpty ? "Session details not found" : parts.joined(separator: ". "))

case "session":
    // The folder pop-up sits in the pane toolbar: a titled pop-up with no description, not the account menu.
    let folder = flat.first { str($0, kAXRoleAttribute) == "AXPopUpButton" && str($0, kAXDescriptionAttribute).isEmpty
        && !str($0, kAXTitleAttribute).isEmpty && !classes($0).contains("df-user-menu-btn") && !composerControls.contains($0) }
    let folderName = folder.map { str($0, kAXTitleAttribute) } ?? railButton("Environment")
    emit(currentSession.isEmpty ? "Session name not found" : "You're in \(currentSession)" + (folderName.map { ", folder \($0)" } ?? ""))

case "rail":
    // The session rail is the panel of session details (Environment, Context, Connectors) beside the chat.
    // Its toolbar toggle is labelled "Show session rail"; AXValue 1 means the rail is showing.
    guard let t = railToggle else { emit("Session rail button not found"); break }
    let wasOn = (attr(t, kAXValueAttribute) as? Int) == 1
    if CommandLine.arguments.contains("--state") { emit(wasOn ? "Session rail is on" : "Session rail is off"); break }
    AXUIElementPerformAction(t, kAXPressAction as CFString)
    Thread.sleep(forTimeInterval: 0.4)
    let nowOn = (attr(t, kAXValueAttribute) as? Int).map { $0 == 1 } ?? !wasOn
    emit(nowOn ? "Session rail on" : "Session rail off")

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

case "check":
    // Look for what each key needs, without moving or pressing anything, and report.
    var ok: [String] = [], missing: [String] = []
    func row(_ key: String, _ found: Bool) { if found { ok.append(key) } else { missing.append(key) } }
    row("P message box", promptIdx != nil)
    row("B sidebar", !sessionButtons.isEmpty)
    row("C Chat or Code buttons", !modeRadios.isEmpty)
    row("O Scheduled", scheduledButton != nil)
    row("S session rail", railToggle != nil)
    row("L latest reply", flat.contains { str($0, kAXRoleAttribute) == "AXHeading" && str($0, kAXTitleAttribute).hasPrefix("Claude responded") })
    row("W sessions", !sessionButtons.isEmpty)
    row("I session info", flat.contains { str($0, kAXRoleAttribute) == "AXPopUpButton" && str($0, kAXDescriptionAttribute).hasPrefix("Model:") })
    row("H which session", !currentSession.isEmpty)
    row("R dictation", composerControls.contains { isStopDictation($0) || str($0, kAXDescriptionAttribute) == "Press and hold to record" })
    var out = missing.isEmpty ? "All \(ok.count) keys found what they need." : "Not found: \(missing.joined(separator: ", ")). Found: \(ok.joined(separator: ", "))."
    if missing.contains("L latest reply") { out += " L needs a reply in the open session." }
    emit(out)

default:
    print("unknown command: \(cmd)")
    exit(64)
}
