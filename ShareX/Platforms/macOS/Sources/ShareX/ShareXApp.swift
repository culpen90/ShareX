import AppKit
import SwiftUI

@main
struct ShareXApp: App {
    @StateObject private var store = CaptureStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 920, minHeight: 620)
        }
        .commands {
            CommandMenu("Capture") {
                Button("Full Screen") {
                    store.capture(.fullScreen)
                }
                .keyboardShortcut("1", modifiers: [.command, .shift])
                .disabled(store.isCapturing)

                Button("Selection") {
                    store.capture(.selection)
                }
                .keyboardShortcut("2", modifiers: [.command, .shift])
                .disabled(store.isCapturing)

                Button("Window") {
                    store.capture(.window)
                }
                .keyboardShortcut("3", modifiers: [.command, .shift])
                .disabled(store.isCapturing)

                Button("Active Window") {
                    store.capture(.activeWindow)
                }
                .keyboardShortcut("4", modifiers: [.command, .shift])
                .disabled(store.isCapturing)

                Button("Active Monitor") {
                    store.capture(.activeMonitor)
                }
                .keyboardShortcut("5", modifiers: [.command, .shift])
                .disabled(store.isCapturing)

                Menu("Choose Monitor") {
                    ForEach(store.availableDisplays) { display in
                        Button(display.title) {
                            store.capture(.monitor, display: display)
                        }
                    }
                }
                .disabled(store.isCapturing)

                Button("Last Region") {
                    store.capture(.lastRegion)
                }
                .keyboardShortcut("6", modifiers: [.command, .shift])
                .disabled(store.isCapturing || !store.hasLastRegion)
            }
        }

        MenuBarExtra("ShareX", systemImage: "camera.viewfinder") {
            Button("Full Screen") {
                store.capture(.fullScreen)
            }
            .disabled(store.isCapturing)

            Button("Selection") {
                store.capture(.selection)
            }
            .disabled(store.isCapturing)

            Button("Window") {
                store.capture(.window)
            }
            .disabled(store.isCapturing)

            Button("Active Window") {
                store.capture(.activeWindow)
            }
            .disabled(store.isCapturing)

            Button("Active Monitor") {
                store.capture(.activeMonitor)
            }
            .disabled(store.isCapturing)

            Menu("Choose Monitor") {
                ForEach(store.availableDisplays) { display in
                    Button(display.title) {
                        store.capture(.monitor, display: display)
                    }
                }
            }
            .disabled(store.isCapturing)

            Button("Last Region") {
                store.capture(.lastRegion)
            }
            .disabled(store.isCapturing || !store.hasLastRegion)

            Divider()

            Button("Open Save Folder") {
                store.openSaveFolder()
            }

            Button("Show ShareX") {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: CaptureStore

    var body: some View {
        NavigationSplitView {
            CaptureSidebar()
                .navigationSplitViewColumnWidth(min: 260, ideal: 280)
        } detail: {
            CaptureHistoryView()
        }
    }
}

struct CaptureSidebar: View {
    @EnvironmentObject private var store: CaptureStore
    private let primaryModes: [CaptureMode] = [
        .fullScreen,
        .selection,
        .window,
        .activeWindow,
        .activeMonitor,
        .lastRegion
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.blue.gradient)
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text("ShareX")
                        .font(.title2.weight(.semibold))
                    Text("macOS")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 10) {
                ForEach(primaryModes) { mode in
                    Button {
                        store.capture(mode)
                    } label: {
                        Label(mode.title, systemImage: mode.symbolName)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(store.isModeDisabled(mode))
                    .help(store.helpText(for: mode))
                }

                Menu {
                    ForEach(store.availableDisplays) { display in
                        Button(display.title) {
                            store.capture(.monitor, display: display)
                        }
                    }
                } label: {
                    Label("Choose Monitor", systemImage: CaptureMode.monitor.symbolName)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(store.isCapturing)
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Toggle("Copy after capture", isOn: $store.copyAfterCapture)
                Toggle("Hide ShareX first", isOn: $store.hideBeforeCapture)
                Toggle("Include cursor", isOn: $store.includeCursor)

                Stepper(value: $store.screenshotDelaySeconds, in: 0...60) {
                    Text("Screenshot delay: \(store.screenshotDelayLabel)")
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button {
                        store.chooseSaveFolder()
                    } label: {
                        Label("Save Folder", systemImage: "folder")
                    }

                    Button {
                        store.openSaveFolder()
                    } label: {
                        Image(systemName: "arrow.up.forward.app")
                    }
                    .help("Open save folder")
                }

                Text(store.saveFolder.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }

            Spacer()

            if let status = store.statusMessage {
                Label(status, systemImage: store.isCapturing ? "camera.metering.center.weighted" : "checkmark.circle")
                    .font(.callout)
                    .foregroundStyle(store.isCapturing ? .primary : .secondary)
                    .lineLimit(2)
            }
        }
        .padding(20)
    }
}

struct CaptureHistoryView: View {
    @EnvironmentObject private var store: CaptureStore

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 14)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recent Captures")
                        .font(.title2.weight(.semibold))
                    Text("\(store.items.count) saved")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    store.clearMissingCaptures()
                } label: {
                    Label("Clean Up", systemImage: "sparkles")
                }
                .disabled(store.items.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)

            Divider()

            if store.items.isEmpty {
                EmptyHistoryView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                        ForEach(store.items) { item in
                            CaptureCard(item: item)
                        }
                    }
                    .padding(24)
                }
            }
        }
    }
}

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(.secondary)
            Text("No captures yet")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

struct CaptureCard: View {
    @EnvironmentObject private var store: CaptureStore
    let item: CaptureItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)

                if let image = NSImage(contentsOf: item.fileURL) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                } else {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                }
            }
            .aspectRatio(16.0 / 10.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.fileURL.lastPathComponent)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)

                    Text(item.capturedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(item.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    Button("Open") {
                        store.open(item)
                    }

                    Button("Copy") {
                        store.copy(item)
                    }

                    Button("Reveal in Finder") {
                        store.reveal(item)
                    }

                    Divider()

                    Button("Delete", role: .destructive) {
                        store.delete(item)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding(10)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(0.55), lineWidth: 1)
        }
    }
}

enum CaptureMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case fullScreen
    case selection
    case window
    case activeWindow
    case activeMonitor
    case monitor
    case lastRegion

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullScreen:
            "Full Screen"
        case .selection:
            "Selection / Region"
        case .window:
            "Window"
        case .activeWindow:
            "Active Window"
        case .activeMonitor:
            "Active Monitor"
        case .monitor:
            "Monitor"
        case .lastRegion:
            "Last Region"
        }
    }

    var symbolName: String {
        switch self {
        case .fullScreen:
            "display"
        case .selection:
            "crop"
        case .window:
            "macwindow"
        case .activeWindow:
            "rectangle.on.rectangle"
        case .activeMonitor:
            "cursorarrow.motionlines"
        case .monitor:
            "rectangle.connected.to.line.below"
        case .lastRegion:
            "selection.pin.in.out"
        }
    }

    var fileComponent: String {
        switch self {
        case .fullScreen:
            "Screen"
        case .selection:
            "Selection"
        case .window:
            "Window"
        case .activeWindow:
            "Active Window"
        case .activeMonitor:
            "Active Monitor"
        case .monitor:
            "Monitor"
        case .lastRegion:
            "Last Region"
        }
    }
}

struct DisplayTarget: Hashable, Identifiable, Sendable {
    var displayID: CGDirectDisplayID
    var captureNumber: Int
    var title: String

    var id: CGDirectDisplayID { displayID }
}

struct CaptureRectangle: Codable, Hashable, Sendable {
    var x: Int
    var y: Int
    var width: Int
    var height: Int

    var argument: String {
        "\(x),\(y),\(width),\(height)"
    }

    @MainActor
    static func from(appKitRect rect: CGRect) -> CaptureRectangle? {
        let normalized = rect.standardized
        guard normalized.width >= 2, normalized.height >= 2 else {
            return nil
        }

        let midpoint = CGPoint(x: normalized.midX, y: normalized.midY)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(midpoint) })
            ?? NSScreen.screens.first(where: { $0.frame.intersects(normalized) }),
              let displayID = screen.displayID else {
            return nil
        }

        let clipped = normalized.intersection(screen.frame)
        guard clipped.width >= 2, clipped.height >= 2 else {
            return nil
        }

        let displayBounds = CGDisplayBounds(displayID)
        let x = displayBounds.minX + (clipped.minX - screen.frame.minX)
        let y = displayBounds.minY + (screen.frame.maxY - clipped.maxY)

        return CaptureRectangle(
            x: Int(x.rounded(.down)),
            y: Int(y.rounded(.down)),
            width: max(1, Int(clipped.width.rounded(.toNearestOrAwayFromZero))),
            height: max(1, Int(clipped.height.rounded(.toNearestOrAwayFromZero)))
        )
    }
}

struct CaptureItem: Codable, Hashable, Identifiable {
    var id: UUID
    var filePath: String
    var capturedAt: Date
    var mode: CaptureMode
    var byteCount: Int64

    var fileURL: URL {
        URL(fileURLWithPath: filePath)
    }

    var summary: String {
        "\(mode.title) - \(ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file))"
    }
}

@MainActor
final class CaptureStore: ObservableObject {
    @Published private(set) var items: [CaptureItem] = []
    @Published private(set) var isCapturing = false
    @Published var statusMessage: String?
    @Published private(set) var lastRegion: CaptureRectangle?

    @Published var copyAfterCapture: Bool {
        didSet { defaults.set(copyAfterCapture, forKey: Defaults.copyAfterCapture) }
    }

    @Published var hideBeforeCapture: Bool {
        didSet { defaults.set(hideBeforeCapture, forKey: Defaults.hideBeforeCapture) }
    }

    @Published var includeCursor: Bool {
        didSet { defaults.set(includeCursor, forKey: Defaults.includeCursor) }
    }

    @Published var screenshotDelaySeconds: Int {
        didSet { defaults.set(screenshotDelaySeconds, forKey: Defaults.screenshotDelaySeconds) }
    }

    @Published var saveFolder: URL {
        didSet { defaults.set(saveFolder.path, forKey: Defaults.saveFolder) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.copyAfterCapture = defaults.object(forKey: Defaults.copyAfterCapture) as? Bool ?? true
        self.hideBeforeCapture = defaults.object(forKey: Defaults.hideBeforeCapture) as? Bool ?? true
        self.includeCursor = defaults.object(forKey: Defaults.includeCursor) as? Bool
            ?? defaults.object(forKey: Defaults.legacyIncludeCursor) as? Bool
            ?? false
        self.screenshotDelaySeconds = defaults.object(forKey: Defaults.screenshotDelaySeconds) as? Int ?? 0

        if let path = defaults.string(forKey: Defaults.saveFolder), !path.isEmpty {
            self.saveFolder = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            self.saveFolder = Self.defaultSaveFolder
        }

        self.lastRegion = Self.loadLastRegion(defaults: defaults)
        loadHistory()
    }

    var availableDisplays: [DisplayTarget] {
        DisplayCatalog.displays()
    }

    var hasLastRegion: Bool {
        lastRegion != nil
    }

    var screenshotDelayLabel: String {
        screenshotDelaySeconds == 1 ? "1 second" : "\(screenshotDelaySeconds) seconds"
    }

    func isModeDisabled(_ mode: CaptureMode) -> Bool {
        isCapturing || (mode == .lastRegion && !hasLastRegion)
    }

    func helpText(for mode: CaptureMode) -> String {
        if mode == .lastRegion && !hasLastRegion {
            return "Capture a selection first to reuse it."
        }

        return mode.title
    }

    func capture(_ mode: CaptureMode, display: DisplayTarget? = nil) {
        guard !isCapturing else {
            return
        }

        if mode == .lastRegion, lastRegion == nil {
            statusMessage = "Capture a selection first"
            return
        }

        isCapturing = true
        statusMessage = "Capturing \(mode.title)"

        let destination = nextDestinationURL(for: mode)
        let includeCursor = includeCursor
        let shouldHide = hideBeforeCapture
        let delay = screenshotDelaySeconds
        let hiddenWindows = shouldHide ? hideVisibleShareXWindows() : []

        Task { @MainActor in
            if shouldHide {
                try? await Task.sleep(nanoseconds: 250_000_000)
            }

            do {
                if delay > 0 {
                    await waitForDelay(seconds: delay, mode: mode)
                }

                let request = try await makeCaptureRequest(mode: mode, display: display, includeCursor: includeCursor)

                let capturedURL = try await Task.detached(priority: .userInitiated) {
                    try CaptureRunner.capture(request: request, destination: destination)
                }.value

                finishCapture(mode: mode, url: capturedURL, hiddenWindows: hiddenWindows)
            } catch CaptureError.cancelled {
                finishCancelledCapture(hiddenWindows: hiddenWindows)
            } catch {
                finishFailedCapture(error, hiddenWindows: hiddenWindows)
            }
        }
    }

    func chooseSaveFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = saveFolder
        panel.prompt = "Use Folder"

        if panel.runModal() == .OK, let url = panel.url {
            saveFolder = url
            statusMessage = "Save folder updated"
        }
    }

    func openSaveFolder() {
        ensureDirectoryExists(saveFolder)
        NSWorkspace.shared.open(saveFolder)
    }

    func open(_ item: CaptureItem) {
        NSWorkspace.shared.open(item.fileURL)
    }

    func reveal(_ item: CaptureItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.fileURL])
    }

    func copy(_ item: CaptureItem) {
        do {
            try copyImageToPasteboard(item.fileURL)
            statusMessage = "Copied \(item.fileURL.lastPathComponent)"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func delete(_ item: CaptureItem) {
        try? FileManager.default.removeItem(at: item.fileURL)
        items.removeAll { $0.id == item.id }
        saveHistory()
        statusMessage = "Deleted capture"
    }

    func clearMissingCaptures() {
        let existingItems = items.filter { FileManager.default.fileExists(atPath: $0.filePath) }
        let removedCount = items.count - existingItems.count
        items = existingItems
        saveHistory()
        statusMessage = removedCount == 1 ? "Removed 1 missing capture" : "Removed \(removedCount) missing captures"
    }

    private func makeCaptureRequest(mode: CaptureMode, display: DisplayTarget?, includeCursor: Bool) async throws -> CaptureRequest {
        switch mode {
        case .fullScreen:
            return CaptureRequest(target: .fullScreen, includeCursor: includeCursor)
        case .selection:
            statusMessage = "Select a region"
            guard let rect = await RegionSelectionController.shared.selectRegion() else {
                throw CaptureError.cancelled
            }

            lastRegion = rect
            saveLastRegion(rect)
            return CaptureRequest(target: .region(rect), includeCursor: includeCursor)
        case .window:
            return CaptureRequest(target: .interactiveWindow, includeCursor: false)
        case .activeWindow:
            return CaptureRequest(target: .activeWindow, includeCursor: includeCursor)
        case .activeMonitor:
            guard let activeDisplay = DisplayCatalog.activeDisplay() else {
                throw CaptureError.noDisplayAvailable
            }

            return CaptureRequest(target: .display(activeDisplay.captureNumber), includeCursor: includeCursor)
        case .monitor:
            guard let display else {
                throw CaptureError.noDisplayAvailable
            }

            return CaptureRequest(target: .display(display.captureNumber), includeCursor: includeCursor)
        case .lastRegion:
            guard let lastRegion else {
                throw CaptureError.noLastRegion
            }

            return CaptureRequest(target: .region(lastRegion), includeCursor: includeCursor)
        }
    }

    private func waitForDelay(seconds: Int, mode: CaptureMode) async {
        for remaining in stride(from: seconds, through: 1, by: -1) {
            statusMessage = "\(mode.title) in \(remaining)s"
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }

    private func finishCapture(mode: CaptureMode, url: URL, hiddenWindows: [NSWindow]) {
        restoreHiddenWindows(hiddenWindows)

        do {
            if copyAfterCapture {
                try copyImageToPasteboard(url)
            }

            let byteCount = fileSize(url)
            let item = CaptureItem(
                id: UUID(),
                filePath: url.path,
                capturedAt: Date(),
                mode: mode,
                byteCount: byteCount
            )

            items.insert(item, at: 0)
            items = Array(items.prefix(80))
            saveHistory()
            statusMessage = copyAfterCapture ? "Saved and copied" : "Saved capture"
        } catch {
            statusMessage = error.localizedDescription
        }

        isCapturing = false
    }

    private func finishCancelledCapture(hiddenWindows: [NSWindow]) {
        restoreHiddenWindows(hiddenWindows)
        statusMessage = "Capture canceled"
        isCapturing = false
    }

    private func finishFailedCapture(_ error: Error, hiddenWindows: [NSWindow]) {
        restoreHiddenWindows(hiddenWindows)
        statusMessage = error.localizedDescription
        isCapturing = false
    }

    private func hideVisibleShareXWindows() -> [NSWindow] {
        let windows = NSApp.windows.filter { window in
            window.isVisible && window.level.rawValue < NSWindow.Level.screenSaver.rawValue
        }

        windows.forEach { $0.orderOut(nil) }
        return windows
    }

    private func restoreHiddenWindows(_ windows: [NSWindow]) {
        guard !windows.isEmpty else {
            return
        }

        windows.forEach { $0.makeKeyAndOrderFront(nil) }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func nextDestinationURL(for mode: CaptureMode) -> URL {
        ensureDirectoryExists(saveFolder)

        let timestamp = Self.fileDateFormatter.string(from: Date())
        let baseName = "ShareX \(mode.fileComponent) \(timestamp)"
        var candidate = saveFolder
            .appendingPathComponent(baseName)
            .appendingPathExtension("png")

        var suffix = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = saveFolder
                .appendingPathComponent("\(baseName) \(suffix)")
                .appendingPathExtension("png")
            suffix += 1
        }

        return candidate
    }

    private func copyImageToPasteboard(_ url: URL) throws {
        guard let image = NSImage(contentsOf: url) else {
            throw CaptureError.unreadableImage(url.path)
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if !pasteboard.writeObjects([image]) {
            throw CaptureError.clipboardWriteFailed
        }
    }

    private func loadHistory() {
        guard let data = try? Data(contentsOf: historyURL) else {
            items = []
            return
        }

        do {
            let decodedItems = try JSONDecoder().decode([CaptureItem].self, from: data)
            items = decodedItems.filter { FileManager.default.fileExists(atPath: $0.filePath) }
        } catch {
            items = []
            statusMessage = "History reset"
        }
    }

    private func saveHistory() {
        ensureDirectoryExists(Self.applicationSupportFolder)

        do {
            let data = try JSONEncoder.shareXEncoder.encode(items)
            try data.write(to: historyURL, options: [.atomic])
        } catch {
            statusMessage = "Could not save history"
        }
    }

    private func saveLastRegion(_ rect: CaptureRectangle) {
        guard let data = try? JSONEncoder.shareXEncoder.encode(rect) else {
            return
        }

        defaults.set(data, forKey: Defaults.lastRegion)
    }

    private func ensureDirectoryExists(_ url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func fileSize(_ url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attributes?[.size] as? Int64 ?? 0
    }

    private var historyURL: URL {
        Self.applicationSupportFolder.appendingPathComponent("history.json")
    }

    private static var defaultSaveFolder: URL {
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
        return (pictures ?? URL(fileURLWithPath: NSHomeDirectory()))
            .appendingPathComponent("ShareX", isDirectory: true)
    }

    private static var applicationSupportFolder: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return (support ?? URL(fileURLWithPath: NSHomeDirectory()))
            .appendingPathComponent("ShareX", isDirectory: true)
    }

    private static let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter
    }()

    private static func loadLastRegion(defaults: UserDefaults) -> CaptureRectangle? {
        guard let data = defaults.data(forKey: Defaults.lastRegion) else {
            return nil
        }

        return try? JSONDecoder().decode(CaptureRectangle.self, from: data)
    }

    private enum Defaults {
        static let copyAfterCapture = "copyAfterCapture"
        static let hideBeforeCapture = "hideBeforeCapture"
        static let includeCursor = "includeCursor"
        static let legacyIncludeCursor = "includeCursorInFullScreen"
        static let screenshotDelaySeconds = "screenshotDelaySeconds"
        static let lastRegion = "lastRegion"
        static let saveFolder = "saveFolder"
    }
}

struct CaptureRequest: Sendable {
    var target: CaptureTarget
    var includeCursor: Bool
}

enum CaptureTarget: Sendable {
    case fullScreen
    case region(CaptureRectangle)
    case interactiveWindow
    case activeWindow
    case display(Int)
}

enum CaptureRunner {
    static func capture(request: CaptureRequest, destination: URL) throws -> URL {
        var arguments = ["-x", "-t", "png"]

        switch request.target {
        case .fullScreen:
            if request.includeCursor {
                arguments.append("-C")
            }
        case .region(let rect):
            if request.includeCursor {
                arguments.append("-C")
            }

            arguments.append(contentsOf: ["-R", rect.argument])
        case .interactiveWindow:
            arguments.append(contentsOf: ["-i", "-w"])
        case .activeWindow:
            if request.includeCursor {
                arguments.append("-C")
            }

            arguments.append(contentsOf: ["-l", "\(try activeWindowID())"])
        case .display(let displayNumber):
            if request.includeCursor {
                arguments.append("-C")
            }

            arguments.append(contentsOf: ["-D", "\(displayNumber)"])
        }

        arguments.append(destination.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !FileManager.default.fileExists(atPath: destination.path) {
                throw CaptureError.cancelled
            }

            throw CaptureError.commandFailed(message ?? "screencapture exited with status \(process.terminationStatus)")
        }

        guard FileManager.default.fileExists(atPath: destination.path) else {
            throw CaptureError.cancelled
        }

        let attributes = try? FileManager.default.attributesOfItem(atPath: destination.path)
        let byteCount = attributes?[.size] as? Int64 ?? 0

        guard byteCount > 0 else {
            try? FileManager.default.removeItem(at: destination)
            throw CaptureError.cancelled
        }

        return destination
    }

    private static func activeWindowID() throws -> CGWindowID {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            throw CaptureError.noActiveWindow
        }

        let ownPID = ProcessInfo.processInfo.processIdentifier
        for window in windows {
            let ownerPID = Self.pidValue(window[kCGWindowOwnerPID as String])
            guard ownerPID != ownPID else {
                continue
            }

            let layer = Self.intValue(window[kCGWindowLayer as String]) ?? 0
            guard layer == 0 else {
                continue
            }

            let alpha = Self.doubleValue(window[kCGWindowAlpha as String]) ?? 1
            guard alpha > 0.05 else {
                continue
            }

            if let boundsDictionary = window[kCGWindowBounds as String] as? NSDictionary,
               let bounds = CGRect(dictionaryRepresentation: boundsDictionary),
               (bounds.width < 40 || bounds.height < 40) {
                continue
            }

            if let windowNumber = Self.uint32Value(window[kCGWindowNumber as String]) {
                return CGWindowID(windowNumber.uint32Value)
            }
        }

        throw CaptureError.noActiveWindow
    }

    private static func pidValue(_ value: Any?) -> pid_t? {
        if let pid = value as? pid_t {
            return pid
        }

        if let number = value as? NSNumber {
            return number.int32Value
        }

        return nil
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int {
            return int
        }

        if let number = value as? NSNumber {
            return number.intValue
        }

        return nil
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let double = value as? Double {
            return double
        }

        if let number = value as? NSNumber {
            return number.doubleValue
        }

        return nil
    }

    private static func uint32Value(_ value: Any?) -> NSNumber? {
        if let number = value as? NSNumber {
            return number
        }

        if let value = value as? UInt32 {
            return NSNumber(value: value)
        }

        return nil
    }
}

enum CaptureError: LocalizedError {
    case cancelled
    case clipboardWriteFailed
    case commandFailed(String)
    case noActiveWindow
    case noDisplayAvailable
    case noLastRegion
    case unreadableImage(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            "Capture canceled"
        case .clipboardWriteFailed:
            "Could not write image to the clipboard"
        case .commandFailed(let message):
            message
        case .noActiveWindow:
            "Could not find an active window to capture"
        case .noDisplayAvailable:
            "Could not find a display to capture"
        case .noLastRegion:
            "Capture a selection first"
        case .unreadableImage(let path):
            "Could not read image at \(path)"
        }
    }
}

@MainActor
enum DisplayCatalog {
    static func displays() -> [DisplayTarget] {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)

        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &displayIDs, &count)
        displayIDs = Array(displayIDs.prefix(Int(count)))

        let mainDisplayID = CGMainDisplayID()
        if let mainIndex = displayIDs.firstIndex(of: mainDisplayID), mainIndex != 0 {
            displayIDs.remove(at: mainIndex)
            displayIDs.insert(mainDisplayID, at: 0)
        }

        return displayIDs.enumerated().map { index, displayID in
            let screen = NSScreen.screens.first { $0.displayID == displayID }
            let fallbackName = index == 0 ? "Main Monitor" : "Monitor \(index + 1)"
            let name = screen?.localizedName ?? fallbackName
            let frame = screen?.frame ?? CGDisplayBounds(displayID)
            let size = "\(Int(frame.width)) x \(Int(frame.height))"

            return DisplayTarget(
                displayID: displayID,
                captureNumber: index + 1,
                title: "\(name) (\(size))"
            )
        }
    }

    static func activeDisplay() -> DisplayTarget? {
        let mouseLocation = NSEvent.mouseLocation
        guard let activeScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }),
              let displayID = activeScreen.displayID else {
            return displays().first
        }

        return displays().first { $0.displayID == displayID } ?? displays().first
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")

        if let id = deviceDescription[key] as? CGDirectDisplayID {
            return id
        }

        if let number = deviceDescription[key] as? NSNumber {
            return CGDirectDisplayID(number.uint32Value)
        }

        return nil
    }
}

@MainActor
final class RegionSelectionController {
    static let shared = RegionSelectionController()
    private var activeSession: RegionSelectionSession?

    private init() {}

    func selectRegion() async -> CaptureRectangle? {
        await withCheckedContinuation { continuation in
            let session = RegionSelectionSession { [weak self] rect in
                self?.activeSession = nil
                continuation.resume(returning: rect)
            }

            activeSession = session
            session.begin()
        }
    }
}

@MainActor
final class RegionSelectionSession {
    private let completion: (CaptureRectangle?) -> Void
    private var window: RegionSelectionWindow?

    init(completion: @escaping (CaptureRectangle?) -> Void) {
        self.completion = completion
    }

    func begin() {
        let frame = NSScreen.screens.reduce(CGRect.null) { partialResult, screen in
            partialResult.union(screen.frame)
        }

        let overlayFrame = frame.isNull ? NSScreen.main?.frame ?? .zero : frame
        let window = RegionSelectionWindow(
            contentRect: overlayFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        let view = RegionSelectionView(frame: CGRect(origin: .zero, size: overlayFrame.size)) { [weak self] rect in
            self?.finish(with: rect)
        }

        window.contentView = view
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        self.window = window
    }

    private func finish(with rect: CGRect?) {
        window?.orderOut(nil)
        window = nil

        guard let rect, let captureRect = CaptureRectangle.from(appKitRect: rect) else {
            completion(nil)
            return
        }

        completion(captureRect)
    }
}

final class RegionSelectionWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

final class RegionSelectionView: NSView {
    private let completion: (CGRect?) -> Void
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?

    init(frame frameRect: NSRect, completion: @escaping (CGRect?) -> Void) {
        self.completion = completion
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        NSCursor.crosshair.set()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = event.locationInWindow
        currentPoint = startPoint
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = event.locationInWindow
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = event.locationInWindow

        guard let selectedRect = selectedRect, selectedRect.width >= 2, selectedRect.height >= 2 else {
            completion(nil)
            return
        }

        let windowOrigin = window?.frame.origin ?? .zero
        let globalRect = selectedRect.offsetBy(dx: windowOrigin.x, dy: windowOrigin.y)
        completion(globalRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            completion(nil)
        } else {
            super.keyDown(with: event)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let selectedRect else {
            NSColor.black.withAlphaComponent(0.28).setFill()
            bounds.fill()
            return
        }

        let overlayPath = NSBezierPath(rect: bounds)
        overlayPath.append(NSBezierPath(rect: selectedRect))
        overlayPath.windingRule = .evenOdd

        NSColor.black.withAlphaComponent(0.28).setFill()
        overlayPath.fill()

        NSColor.systemBlue.setStroke()
        let border = NSBezierPath(rect: selectedRect)
        border.lineWidth = 2
        border.stroke()

        NSColor.systemBlue.withAlphaComponent(0.14).setFill()
        selectedRect.fill()
    }

    private var selectedRect: CGRect? {
        guard let startPoint, let currentPoint else {
            return nil
        }

        return CGRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )
    }
}

extension JSONEncoder {
    static var shareXEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
