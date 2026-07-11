import AppKit
import LiveConnectionsMonitorCore
import SwiftUI

@main
struct LiveConnectionsMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel: FirewallDashboardViewModel
    @StateObject private var throughputMonitor: NetworkThroughputMonitor
    @StateObject private var desktopThroughputBarController: DesktopThroughputBarController
    @StateObject private var applicationNetworkViewModel: ApplicationNetworkViewModel

    init() {
        let throughputMonitor = NetworkThroughputMonitor()
        _throughputMonitor = StateObject(wrappedValue: throughputMonitor)
        _desktopThroughputBarController = StateObject(wrappedValue: DesktopThroughputBarController(monitor: throughputMonitor))
        let database: FirewallDatabase
        do {
            database = try FirewallDatabase()
            try? database.recordStartup()
        } catch {
            fatalError("Unable to open firewall dashboard database: \(error.localizedDescription)")
        }
        let firewallService = FirewallBlockService()
        let connectionMonitor = ConnectionMonitorService()
        let liveViewModel = LiveConnectionsViewModel(
            monitorService: connectionMonitor,
            firewallService: firewallService
        )
        let applicationDatabase: ApplicationNetworkDatabase
        do {
            applicationDatabase = try ApplicationNetworkDatabase()
        } catch {
            fatalError("Unable to open application network history: \(error.localizedDescription)")
        }
        _applicationNetworkViewModel = StateObject(wrappedValue: ApplicationNetworkViewModel(
            provider: ProcessCounterAppNetworkProvider(connectionMonitor: connectionMonitor),
            database: applicationDatabase
        ))
        _viewModel = StateObject(wrappedValue: FirewallDashboardViewModel(
            database: database,
            liveConnectionsViewModel: liveViewModel,
            firewallService: firewallService
        ))
    }

    var body: some Scene {
        WindowGroup("GlossWire") {
            FirewallDashboardView(viewModel: viewModel)
                .environmentObject(throughputMonitor)
                .environmentObject(applicationNetworkViewModel)
                .frame(minWidth: 1180, minHeight: 720)
                .background(WindowCloseHider())
                .onAppear { desktopThroughputBarController.start() }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandMenu("Connections") {
                Button("Show Connections") {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    NSApplication.shared.windows.first { $0.canBecomeMain && !($0 is NSPanel) }?.makeKeyAndOrderFront(nil)
                }
                .keyboardShortcut("0", modifiers: [.command])

                Button("Refresh Now") {
                    viewModel.reload()
                    Task { await viewModel.liveConnectionsViewModel.refreshNow() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }

        MenuBarExtra {
            NetworkThroughputPopover(
                monitor: throughputMonitor,
                showConnections: showConnections,
                refreshConnections: refreshConnections,
                quit: { NSApplication.shared.terminate(nil) }
            )
        } label: {
            ThroughputMenuBarLabel(monitor: throughputMonitor)
        }
        .menuBarExtraStyle(.window)
    }

    private func showConnections() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }

    private func refreshConnections() {
        viewModel.reload()
        Task { await viewModel.liveConnectionsViewModel.refreshNow() }
    }

    private var mainWindow: NSWindow? {
        NSApplication.shared.windows.first { window in
            window.canBecomeMain && !(window is NSPanel)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard Self.wasLaunchedAsLoginItem else { return }
        DispatchQueue.main.async {
            NSApplication.shared.windows.forEach { window in
                guard window.canBecomeMain, !(window is NSPanel) else { return }
                window.orderOut(nil)
            }
            NSApplication.shared.hide(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private static var wasLaunchedAsLoginItem: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
        return event.paramDescriptor(forKeyword: keyAELaunchedAsLogInItem) != nil
    }
}

struct WindowCloseHider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.delegate = context.coordinator
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.delegate = context.coordinator
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        func windowShouldClose(_ sender: NSWindow) -> Bool {
            sender.orderOut(nil)
            return false
        }
    }
}
