import AppKit

@main struct NetMeterApp {
    static func main() {
        #if DIAGNOSTICS
        if CommandLine.arguments.contains("--probe") {
            RuntimeDiagnostics.run()
            return
        }
        #endif
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
