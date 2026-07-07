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

                Button("Selection") {
                    store.capture(.selection)
                }
                .keyboardShortcut("2", modifiers: [.command, .shift])

                Button("Window") {
                    store.capture(.window)
                }
                .keyboardShortcut("3", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra("ShareX", systemImage: "camera.viewfinder") {
            Button("Full Screen") {
                store.capture(.fullScreen)
            }

            Button("Selection") {
                store.capture(.selection)
            }

            Button("Window") {
                store.capture(.window)
            }

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
                ForEach(CaptureMode.allCases) { mode in
                    Button {
                        store.capture(mode)
                    } label: {
                        Label(mode.title, systemImage: mode.symbolName)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(store.isCapturing)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Toggle("Copy after capture", isOn: $store.copyAfterCapture)
                Toggle("Hide ShareX first", isOn: $store.hideBeforeCapture)
                Toggle("Include cursor", isOn: $store.includeCursorInFullScreen)
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

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullScreen:
            "Full Screen"
        case .selection:
            "Selection"
        case .window:
            "Window"
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
        }
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

    @Published var copyAfterCapture: Bool {
        didSet { defaults.set(copyAfterCapture, forKey: Defaults.copyAfterCapture) }
    }

    @Published var hideBeforeCapture: Bool {
        didSet { defaults.set(hideBeforeCapture, forKey: Defaults.hideBeforeCapture) }
    }

    @Published var includeCursorInFullScreen: Bool {
        didSet { defaults.set(includeCursorInFullScreen, forKey: Defaults.includeCursor) }
    }

    @Published var saveFolder: URL {
        didSet { defaults.set(saveFolder.path, forKey: Defaults.saveFolder) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.copyAfterCapture = defaults.object(forKey: Defaults.copyAfterCapture) as? Bool ?? true
        self.hideBeforeCapture = defaults.object(forKey: Defaults.hideBeforeCapture) as? Bool ?? true
        self.includeCursorInFullScreen = defaults.object(forKey: Defaults.includeCursor) as? Bool ?? false

        if let path = defaults.string(forKey: Defaults.saveFolder), !path.isEmpty {
            self.saveFolder = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            self.saveFolder = Self.defaultSaveFolder
        }

        loadHistory()
    }

    func capture(_ mode: CaptureMode) {
        guard !isCapturing else {
            return
        }

        isCapturing = true
        statusMessage = "Capturing \(mode.title)"

        let destination = nextDestinationURL(for: mode)
        let includeCursor = mode == .fullScreen && includeCursorInFullScreen
        let shouldHide = hideBeforeCapture

        if shouldHide {
            NSApp.hide(nil)
        }

        Task {
            if shouldHide {
                try? await Task.sleep(nanoseconds: 250_000_000)
            }

            do {
                let capturedURL = try await Task.detached(priority: .userInitiated) {
                    try CaptureRunner.capture(mode: mode, destination: destination, includeCursor: includeCursor)
                }.value

                finishCapture(mode: mode, url: capturedURL, shouldUnhide: shouldHide)
            } catch CaptureError.cancelled {
                finishCancelledCapture(shouldUnhide: shouldHide)
            } catch {
                finishFailedCapture(error, shouldUnhide: shouldHide)
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

    private func finishCapture(mode: CaptureMode, url: URL, shouldUnhide: Bool) {
        if shouldUnhide {
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)
        }

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

    private func finishCancelledCapture(shouldUnhide: Bool) {
        if shouldUnhide {
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)
        }

        statusMessage = "Capture canceled"
        isCapturing = false
    }

    private func finishFailedCapture(_ error: Error, shouldUnhide: Bool) {
        if shouldUnhide {
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)
        }

        statusMessage = error.localizedDescription
        isCapturing = false
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

    private enum Defaults {
        static let copyAfterCapture = "copyAfterCapture"
        static let hideBeforeCapture = "hideBeforeCapture"
        static let includeCursor = "includeCursorInFullScreen"
        static let saveFolder = "saveFolder"
    }
}

enum CaptureRunner {
    static func capture(mode: CaptureMode, destination: URL, includeCursor: Bool) throws -> URL {
        var arguments = ["-x", "-t", "png"]

        switch mode {
        case .fullScreen:
            if includeCursor {
                arguments.append("-C")
            }
        case .selection:
            arguments.append(contentsOf: ["-i", "-s"])
        case .window:
            arguments.append(contentsOf: ["-i", "-w"])
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
}

enum CaptureError: LocalizedError {
    case cancelled
    case clipboardWriteFailed
    case commandFailed(String)
    case unreadableImage(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            "Capture canceled"
        case .clipboardWriteFailed:
            "Could not write image to the clipboard"
        case .commandFailed(let message):
            message
        case .unreadableImage(let path):
            "Could not read image at \(path)"
        }
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
