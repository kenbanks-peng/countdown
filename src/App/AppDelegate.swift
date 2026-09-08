import AppKit

/// Connects the application lifecycle to its floating countdown window.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: CountdownWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        windowController = CountdownWindowController(countdown: CountdownController())
    }

    func applicationWillTerminate(_ notification: Notification) {
        windowController?.save()
    }
}
