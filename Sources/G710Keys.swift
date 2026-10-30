import Foundation
import AppKit
import IOKit.hid
import CoreGraphics
import ApplicationServices

// MARK: - Logging
let logDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs")
let logURL = logDir.appendingPathComponent("G710Keys.log")
func log(_ s: String) {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    let line = "[" + f.string(from: Date()) + "] " + s + "\n"
    try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
    if let h = try? FileHandle(forWritingTo: logURL) {
        h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close()
    } else {
        try? line.data(using: .utf8)!.write(to: logURL)
    }
    FileHandle.standardError.write(line.data(using: .utf8)!)
}

// MARK: - Config
struct Binding: Codable {
    var key: String?
    var mods: [String]?
    var shell: String?
    var isEmpty: Bool { (key ?? "").isEmpty && (shell ?? "").isEmpty }
}
struct Config: Codable {
    var profiles: [String: [Binding]]
    var repeatEnabled: Bool?
    var repeatDelayMs: Int?
    var repeatIntervalMs: Int?
}
func defaultBindings() -> [Binding] {
    return ["f13", "f14", "f15", "f16", "f17", "f18"].map { Binding(key: $0, mods: nil, shell: nil) }
}
func makeDefaultConfig() -> Config {
    return Config(profiles: ["1": defaultBindings(), "2": defaultBindings(), "3": defaultBindings()],
                  repeatEnabled: true, repeatDelayMs: 400, repeatIntervalMs: 70)
}

let supportDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/G710Keys")
let configURL = supportDir.appendingPathComponent("config.json")

var config: Config = makeDefaultConfig()
func loadConfig() {
    try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
    if let data = try? Data(contentsOf: configURL),
       let c = try? JSONDecoder().decode(Config.self, from: data) {
        config = c
    } else {
        config = makeDefaultConfig()
        if let data = try? JSONEncoder().encode(config) { try? data.write(to: configURL) }
    }
}
func saveConfig(_ c: Config) {
    config = c
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let data = try? enc.encode(c) { try? data.write(to: configURL) }
    log("config saved: " + configURL.path)
}

// MARK: - Key map
let keyMap: [String: CGKeyCode] = [
    "a":0x00,"s":0x01,"d":0x02,"f":0x03,"h":0x04,"g":0x05,"z":0x06,"x":0x07,"c":0x08,"v":0x09,
    "b":0x0B,"q":0x0C,"w":0x0D,"e":0x0E,"r":0x0F,"y":0x10,"t":0x11,
    "1":0x12,"2":0x13,"3":0x14,"4":0x15,"6":0x16,"5":0x17,"equal":0x18,"9":0x19,"7":0x1A,
    "minus":0x1B,"8":0x1C,"0":0x1D,"rightbracket":0x1E,"o":0x1F,"u":0x20,"leftbracket":0x21,
    "i":0x22,"p":0x23,"return":0x24,"l":0x25,"j":0x26,"quote":0x27,"k":0x28,"semicolon":0x29,
    "backslash":0x2A,"comma":0x2B,"slash":0x2C,"n":0x2D,"m":0x2E,"period":0x2F,"tab":0x30,
    "space":0x31,"grave":0x32,"delete":0x33,"escape":0x35,
    "f1":0x7A,"f2":0x78,"f3":0x63,"f4":0x76,"f5":0x60,"f6":0x61,"f7":0x62,"f8":0x64,"f9":0x65,
    "f10":0x6D,"f11":0x67,"f12":0x6F,"f13":0x69,"f14":0x6B,"f15":0x71,"f16":0x6A,"f17":0x40,
    "f18":0x4F,"f19":0x50,"f20":0x5A,
    "home":0x73,"end":0x77,"pageup":0x74,"pagedown":0x79,"forwarddelete":0x75,
    "left":0x7B,"right":0x7C,"down":0x7D,"up":0x7E,
    "numpad0":0x52,"numpad1":0x53,"numpad2":0x54,"numpad3":0x55,"numpad4":0x56,
    "numpad5":0x57,"numpad6":0x58,"numpad7":0x59,"numpad8":0x5B,"numpad9":0x5C,
    "numpadmultiply":0x43,"numpadplus":0x45,"numpadminus":0x4E,"numpaddot":0x41,
    "numpaddivide":0x4B,"numpadenter":0x4C
]
let reverseKeyMap: [UInt16: String] = {
    var d: [UInt16: String] = [:]
    for (name, code) in keyMap where d[code] == nil { d[code] = name }
    return d
}()
func modFlag(_ s: String) -> CGEventFlags? {
    switch s.lowercased() {
    case "cmd", "command", "⌘": return .maskCommand
    case "shift", "⇧": return .maskShift
    case "ctrl", "control", "⌃": return .maskControl
    case "opt", "option", "alt", "⌥": return .maskAlternate
    default: return nil
    }
}
let eventSource = CGEventSource(stateID: .hidSystemState)
func postKey(_ code: CGKeyCode, mods: CGEventFlags) {
    guard let down = CGEvent(keyboardEventSource: eventSource, virtualKey: code, keyDown: true),
          let up = CGEvent(keyboardEventSource: eventSource, virtualKey: code, keyDown: false) else { return }
    down.flags = mods
    up.flags = mods
    down.post(tap: .cghidEventTap)
    usleep(8000)
    up.post(tap: .cghidEventTap)
}
func perform(_ b: Binding) {
    if let k = b.key, let code = keyMap[k.lowercased()] {
        var f: CGEventFlags = []
        for m in (b.mods ?? []) { if let mf = modFlag(m) { f.insert(mf) } }
        postKey(code, mods: f)
    }
    if let sh = b.shell, !sh.isEmpty {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", sh]
        try? p.run()
    }
}

// MARK: - Engine
final class Engine {
    static let shared = Engine()
    var manager: IOHIDManager?
    var device: IOHIDDevice?
    var buffer: UnsafeMutablePointer<UInt8>?
    var profile = 1
    var connected = false
    var prevG: UInt8 = 0
    var prevM: UInt8 = 0
    var heldG: UInt8 = 0
    var repeatStart: [Int: Date] = [:]
    var repeatTimer: DispatchSourceTimer?
    var onUpdate: (() -> Void)?

    func start() {
        let mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        manager = mgr
        IOHIDManagerSetDeviceMatching(mgr, [
            kIOHIDVendorIDKey as String: 0x046d,
            kIOHIDProductIDKey as String: 0xc24d
        ] as CFDictionary)
        IOHIDManagerScheduleWithRunLoop(mgr, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerRegisterDeviceMatchingCallback(mgr, { _, _, _, dev in
            Engine.shared.matched(dev)
        }, nil)
        IOHIDManagerRegisterDeviceRemovalCallback(mgr, { _, _, _, dev in
            if Engine.shared.device == dev {
                Engine.shared.device = nil
                Engine.shared.connected = false
                Engine.shared.onUpdate?()
            }
        }, nil)
        let r = IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
        log("manager open -> \(r)")
        startRepeatLoop()
    }

    func matched(_ dev: IOHIDDevice) {
        let n = (IOHIDDeviceGetProperty(dev, kIOHIDReportDescriptorKey as CFString) as? Data)?.count ?? 0
        log("device matched descriptor len=\(n)")
        guard n > 100 else { return }
        let open = IOHIDDeviceOpen(dev, IOOptionBits(kIOHIDOptionsTypeNone))
        log("device open -> \(open)")
        guard open == kIOReturnSuccess else { return }
        device = dev
        connected = true
        onUpdate?()
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
        buf.initialize(repeating: 0, count: 64)
        buffer = buf
        IOHIDDeviceRegisterInputReportCallback(dev, buf, 64, { _, _, _, _, rid, report, len in
            Engine.shared.handle(reportID: Int(rid), report: report, length: Int(len))
        }, nil)
        disableGhostMirroring(dev)
        setProfile(profile)
    }

    func disableGhostMirroring(_ dev: IOHIDDevice) {
        var zeros = [UInt8](repeating: 0, count: 13)
        var r: IOReturn = zeros.withUnsafeBufferPointer {
            IOHIDDeviceSetReport(dev, kIOHIDReportTypeFeature, 9, $0.baseAddress!, 13)
        }
        if r != kIOReturnSuccess {
            zeros = [UInt8](repeating: 0, count: 12)
            r = zeros.withUnsafeBufferPointer {
                IOHIDDeviceSetReport(dev, kIOHIDReportTypeFeature, 9, $0.baseAddress!, 12)
            }
        }
        log("disable ghost mirroring -> \(r)")
    }

    func setProfile(_ p: Int) {
        profile = p
        onUpdate?()
        guard let dev = device else { return }
        let bit: UInt8 = p == 1 ? 0x10 : (p == 2 ? 0x20 : 0x40)
        let d: [UInt8] = [0x06, bit]
        let r: IOReturn = d.withUnsafeBufferPointer {
            IOHIDDeviceSetReport(dev, kIOHIDReportTypeFeature, 6, $0.baseAddress!, 2)
        }
        log("set M\(p) LED -> \(r)")
    }

    func bindingsForCurrentProfile() -> [Binding] {
        return config.profiles[String(profile)] ?? defaultBindings()
    }

    func handle(reportID: Int, report: UnsafeMutablePointer<UInt8>, length: Int) {
        guard length >= 1 else { return }
        var rid = reportID
        var start = 0
        if rid == 0 {
            let first = Int(report[0])
            if first == 3 || first == 4 {
                rid = first
                start = 1
            } else {
                return
            }
        } else if Int(report[0]) == rid {
            start = 1
        }
        guard rid == 3, length - start >= 3 else { return }
        let g = report[start]
        let m = report[start + 1]
        let status = report[start + 2]
        if g != prevG || m != prevM {
            log("report rid=3 G=\(g) M=\(m) status=\(status)")
        }

        let pressed = g & ~prevG
        if pressed != 0 {
            let bs = bindingsForCurrentProfile()
            for i in 0..<6 where pressed & UInt8(1 << i) != 0 {
                if i < bs.count { perform(bs[i]) }
                heldG |= UInt8(1 << i)
                repeatStart[i] = Date()
            }
        }
        let released = prevG & ~g
        if released != 0 {
            for i in 0..<6 where released & UInt8(1 << i) != 0 {
                heldG &= ~UInt8(1 << i)
                repeatStart[i] = nil
            }
        }
        prevG = g

        let mChanged = m & ~prevM
        if mChanged != 0 {
            if mChanged & 0x10 != 0 {
                setProfile(1)
            } else if mChanged & 0x20 != 0 {
                setProfile(2)
            } else if mChanged & 0x40 != 0 {
                setProfile(3)
            } else if mChanged & 0x80 != 0 {
                log("MR pressed")
            }
        }
        prevM = m
    }

    func startRepeatLoop() {
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + .milliseconds(50), repeating: .milliseconds(20))
        t.setEventHandler { [weak self] in
            guard let self = self else { return }
            guard config.repeatEnabled ?? true else { return }
            guard self.heldG != 0 else { return }
            let now = Date()
            let bs = self.bindingsForCurrentProfile()
            for i in 0..<6 where self.heldG & UInt8(1 << i) != 0 {
                guard let s = self.repeatStart[i] else { continue }
                if now.timeIntervalSince(s) * 1000 > Double(config.repeatDelayMs ?? 400) {
                    if i < bs.count, bs[i].shell == nil, !bs[i].isEmpty {
                        perform(bs[i])
                    }
                }
            }
        }
        t.resume()
        repeatTimer = t
    }
}

// MARK: - Text helpers
func bindingToText(_ b: Binding) -> String {
    if let sh = b.shell, !sh.isEmpty { return "shell:" + sh }
    guard let k = b.key, !k.isEmpty else { return "" }
    let mods = (b.mods ?? []).joined(separator: "+")
    return mods.isEmpty ? k : mods + "+" + k
}
func textToBinding(_ t: String) -> Binding {
    let s = t.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.isEmpty { return Binding(key: nil, mods: nil, shell: nil) }
    if s.lowercased().hasPrefix("shell:") {
        return Binding(key: nil, mods: nil, shell: String(s.dropFirst(6)))
    }
    let parts = s.split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    guard !parts.isEmpty else { return Binding(key: nil, mods: nil, shell: nil) }
    let key = String(parts.last!).lowercased()
    var mods: [String] = []
    for p in parts.dropLast() {
        switch p.lowercased() {
        case "cmd", "command", "⌘": mods.append("cmd")
        case "shift", "⇧": mods.append("shift")
        case "ctrl", "control", "⌃": mods.append("ctrl")
        case "opt", "option", "alt", "⌥": mods.append("opt")
        default: break
        }
    }
    return Binding(key: key, mods: mods.isEmpty ? nil : mods, shell: nil)
}

// MARK: - App
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var window: NSWindow?
    var deviceLabel: NSTextField!
    var profileLabel: NSTextField!
    var inputLabel: NSTextField!
    var axLabel: NSTextField!
    var segmented: NSSegmentedControl!
    var fields: [NSTextField] = []
    var edits: [String: [String]] = [:]
    var currentProfile = "1"
    var refreshTimer: Timer?
    var recordingIndex: Int?
    var recordButtons: [NSButton] = []
    var localMonitor: Any?

    func applicationDidFinishLaunching(_ n: Notification) {
        loadConfig()
        for p in ["1", "2", "3"] {
            let bs = config.profiles[p] ?? defaultBindings()
            edits[p] = (0..<6).map { i in i < bs.count ? bindingToText(bs[i]) : "" }
        }
        buildStatusItem()
        buildWindow()
        Engine.shared.onUpdate = { [weak self] in self?.refresh() }
        Engine.shared.start()
        refresh()
        showWindow()
        requestPermissionsIfNeeded()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.refresh() }
        log("app launched")
    }

    func applicationDidResignActive(_ notification: Notification) {
        if recordingIndex != nil { stopRecording(cancel: true) }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    func requestPermissionsIfNeeded() {
        if IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) != kIOHIDAccessTypeGranted {
            _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        }
        if !CGPreflightPostEventAccess() {
            _ = CGRequestPostEventAccess()
        }
    }

    func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let b = statusItem.button {
            b.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "G710Keys")
            b.image?.isTemplate = true
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(withTitle: (Engine.shared.connected ? "G710+ 已连接" : "G710+ 未连接"), action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "当前档位：M\(Engine.shared.profile)", action: nil, keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        let show = menu.addItem(withTitle: "打开设置…", action: #selector(showWindowAction), keyEquivalent: ",")
        show.target = self
        let reload = menu.addItem(withTitle: "重新读取配置", action: #selector(reloadConfigAction), keyEquivalent: "r")
        reload.target = self
        let openCfg = menu.addItem(withTitle: "打开配置文件", action: #selector(openConfigAction), keyEquivalent: "")
        openCfg.target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "退出 G710Keys", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    @objc func showWindowAction() {
        showWindow()
    }
    @objc func reloadConfigAction() {
        loadConfig()
        for p in ["1", "2", "3"] {
            let bs = config.profiles[p] ?? defaultBindings()
            edits[p] = (0..<6).map { i in i < bs.count ? bindingToText(bs[i]) : "" }
        }
        loadFields(profile: currentProfile)
        refresh()
    }
    @objc func openConfigAction() {
        NSWorkspace.shared.activateFileViewerSelecting([configURL])
    }

    func showWindow() {
        if window == nil { buildWindow() }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func buildWindow() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 560),
                         styleMask: [.titled, .closable, .miniaturizable],
                         backing: .buffered, defer: false)
        w.title = "G710Keys 设置"
        w.center()
        w.isReleasedWhenClosed = false
        window = w

        let content = NSView(frame: NSRect(x: 0, y: 0, width: 580, height: 560))
        w.contentView = content

        let top = NSStackView()
        top.orientation = .vertical
        top.alignment = .leading
        top.spacing = 6
        top.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(top)

        let title = NSTextField(labelWithString: "罗技 G710+ / macOS 按键助手")
        title.font = NSFont.boldSystemFont(ofSize: 16)
        top.addArrangedSubview(title)

        deviceLabel = NSTextField(labelWithString: "键盘：检测中…")
        profileLabel = NSTextField(labelWithString: "当前档位：M1")
        top.addArrangedSubview(deviceLabel)
        top.addArrangedSubview(profileLabel)

        inputLabel = NSTextField(labelWithString: "输入监控：检查中…")
        axLabel = NSTextField(labelWithString: "辅助功能：检查中…")
        top.addArrangedSubview(inputLabel)
        top.addArrangedSubview(axLabel)

        let permRow = NSStackView()
        permRow.orientation = .horizontal
        permRow.spacing = 8
        let btnInput = NSButton(title: "输入监控设置", target: self, action: #selector(openInputSettings))
        let btnAx = NSButton(title: "辅助功能设置", target: self, action: #selector(openAccessibilitySettings))
        let btnRestart = NSButton(title: "授权后重启", target: self, action: #selector(relaunch))
        permRow.addArrangedSubview(btnInput)
        permRow.addArrangedSubview(btnAx)
        permRow.addArrangedSubview(btnRestart)
        top.addArrangedSubview(permRow)

        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        top.addArrangedSubview(sep)

        let segLabel = NSTextField(labelWithString: "编辑档位：")
        segmented = NSSegmentedControl(labels: ["M1", "M2", "M3"], trackingMode: .selectOne, target: self, action: #selector(profileSegmentChanged))
        segmented.selectedSegment = 0
        let segRow = NSStackView(views: [segLabel, segmented])
        segRow.orientation = .horizontal
        segRow.spacing = 10
        top.addArrangedSubview(segRow)

        let grid = NSGridView()
        grid.rowSpacing = 8
        grid.columnSpacing = 12
        grid.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(grid)

        for i in 0..<6 {
            let label = NSTextField(labelWithString: "G\(i + 1)")
            label.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
            let tf = NSTextField(string: "")
            tf.placeholderString = "例如 f13、cmd+shift+4、shell:open -a Safari"
            tf.widthAnchor.constraint(equalToConstant: 300).isActive = true
            fields.append(tf)
            let rec = NSButton(title: "录制", target: self, action: #selector(startRecording(_:)))
            rec.tag = i
            rec.bezelStyle = .rounded
            rec.toolTip = "点一下，然后按下想绑定的键（Esc 取消，Delete 清空）"
            recordButtons.append(rec)
            grid.addRow(with: [label, tf, rec])
        }

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 10
        buttons.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(buttons)
        let save = NSButton(title: "保存并应用", target: self, action: #selector(saveEdits))
        save.bezelStyle = .rounded
        let reset = NSButton(title: "恢复默认", target: self, action: #selector(resetDefaults))
        let openCfg = NSButton(title: "打开配置文件", target: self, action: #selector(openConfigAction))
        buttons.addArrangedSubview(save)
        buttons.addArrangedSubview(reset)
        buttons.addArrangedSubview(openCfg)

        let hint = NSTextField(wrappingLabelWithString: "说明：点「录制」后直接按键盘组合键，会自动填入（Esc 取消，Delete 清空）。G1–G6 默认 F13–F18，M1/M2/M3 切换档位。键名支持 f1–f20、字母、数字、方向键、numpad；以 shell: 开头则执行命令。录制或保存后立即生效，无需重启。")
        hint.translatesAutoresizingMaskIntoConstraints = false
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        content.addSubview(hint)

        NSLayoutConstraint.activate([
            top.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            top.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            top.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            grid.topAnchor.constraint(equalTo: top.bottomAnchor, constant: 12),
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            buttons.topAnchor.constraint(equalTo: grid.bottomAnchor, constant: 14),
            buttons.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            hint.topAnchor.constraint(equalTo: buttons.bottomAnchor, constant: 12),
            hint.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            hint.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16)
        ])
        loadFields(profile: "1")
    }

    // MARK: - 录制按键

    @objc func startRecording(_ sender: NSButton) {
        let i = sender.tag
        if recordingIndex == i {
            stopRecording(cancel: true)
            return
        }
        stopRecording(cancel: true)
        recordingIndex = i
        for (j, b) in recordButtons.enumerated() { b.title = (j == i) ? "按键…" : "录制" }
        showWindow()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] ev in
                guard let self = self else { return ev }
                if self.recordingIndex == nil { return ev }
                return self.handleRecord(ev) ? nil : ev
            }
        }
        log("recording started for G\(i + 1)")
    }

    func handleRecord(_ ev: NSEvent) -> Bool {
        guard let idx = recordingIndex, idx < fields.count else { return false }
        let modifierKeyCodes: Set<UInt16> = [55, 54, 56, 57, 58, 59, 60, 61, 62]
        if modifierKeyCodes.contains(ev.keyCode) { return true }
        if ev.keyCode == 53 {
            stopRecording(cancel: true)
            return true
        }
        let mods = ev.modifierFlags.intersection([.command, .control, .option, .shift])
        if ev.keyCode == 51 && mods.isEmpty {
            fields[idx].stringValue = ""
            finishRecording(index: idx)
            return true
        }
        let keyName = reverseKeyMap[ev.keyCode] ?? "key\(ev.keyCode)"
        var parts: [String] = []
        if mods.contains(.command) { parts.append("cmd") }
        if mods.contains(.control) { parts.append("ctrl") }
        if mods.contains(.option) { parts.append("opt") }
        if mods.contains(.shift) { parts.append("shift") }
        parts.append(keyName)
        fields[idx].stringValue = parts.joined(separator: "+")
        finishRecording(index: idx)
        return true
    }

    func finishRecording(index: Int) {
        var arr = edits[currentProfile] ?? ["", "", "", "", "", ""]
        if index < arr.count { arr[index] = fields[index].stringValue }
        edits[currentProfile] = arr
        stopRecording(cancel: false)
        persistEdits(showConfirmation: false)
        log("recorded binding: \(fields[index].stringValue)")
    }

    func stopRecording(cancel: Bool) {
        if let i = recordingIndex, cancel, i < fields.count {
            let arr = edits[currentProfile] ?? []
            if i < arr.count { fields[i].stringValue = arr[i] }
        }
        recordingIndex = nil
        for b in recordButtons { b.title = "录制" }
        if let m = localMonitor {
            NSEvent.removeMonitor(m)
            localMonitor = nil
        }
    }

    func loadFields(profile: String) {
        currentProfile = profile
        let vals = edits[profile] ?? ["", "", "", "", "", ""]
        for (i, f) in fields.enumerated() { f.stringValue = i < vals.count ? vals[i] : "" }
        segmented.selectedSegment = Int(profile)! - 1
    }

    func storeFields() {
        edits[currentProfile] = fields.map { $0.stringValue }
    }

    @objc func profileSegmentChanged() {
        storeFields()
        loadFields(profile: String(segmented.selectedSegment + 1))
    }

    @objc func saveEdits() {
        persistEdits(showConfirmation: true)
    }

    func persistEdits(showConfirmation: Bool) {
        storeFields()
        var c = config
        var profiles: [String: [Binding]] = [:]
        for p in ["1", "2", "3"] {
            let texts = edits[p] ?? []
            profiles[p] = (0..<6).map { i in
                i < texts.count ? textToBinding(texts[i]) : Binding(key: nil, mods: nil, shell: nil)
            }
        }
        c.profiles = profiles
        saveConfig(c)
        refresh()
        if showConfirmation {
            let alert = NSAlert()
            alert.messageText = "已保存"
            alert.informativeText = "配置已写入：\n" + configURL.path
            alert.runModal()
        }
    }

    @objc func resetDefaults() {
        let d = (0..<6).map { bindingToText(defaultBindings()[$0]) }
        edits = ["1": d, "2": d, "3": d]
        loadFields(profile: currentProfile)
    }

    @objc func openInputSettings() {
        if let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(u)
        }
    }
    @objc func openAccessibilitySettings() {
        if let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(u)
        }
    }
    @objc func relaunch() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", Bundle.main.bundlePath]
        try? task.run()
        NSApp.terminate(nil)
    }

    func refresh() {
        deviceLabel?.stringValue = "键盘：" + (Engine.shared.connected ? "G710+ 已连接 ✓" : "未检测到（检查 USB 连接）")
        profileLabel?.stringValue = "当前档位：M\(Engine.shared.profile)"
        let inputOK = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        let axOK = CGPreflightPostEventAccess()
        inputLabel?.stringValue = "输入监控：" + (inputOK ? "已授权 ✓" : "未授权 ✗（读 G 键需要）")
        axLabel?.stringValue = "辅助功能：" + (axOK ? "已授权 ✓" : "未授权 ✗（合成按键需要）")
        inputLabel?.textColor = inputOK ? NSColor.labelColor : NSColor.systemRed
        axLabel?.textColor = axOK ? NSColor.labelColor : NSColor.systemRed
    }
}

// MARK: - main
let app = NSApplication.shared
let appDelegate = AppDelegate()
app.delegate = appDelegate
app.setActivationPolicy(.accessory)
app.run()
