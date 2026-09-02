import AIElementsGallery
import AppKit
import ShadcnUI
import SwiftUI

/// Standalone host for the gallery, so the component set can be eyeballed
/// without embedding it in an app first.
///
/// Built as a plain `NSApplication` rather than an `App` scene because SwiftPM
/// executables have no bundle, and `@main` scenes need one to activate.
final class DemoAppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "ShadKit"
        // `ShadKitDemo --section glass --scheme dark --opacity 0.45` opens
        // straight onto the glass page, which is what the screenshot pass drives.
        let arguments = CommandLine.arguments
        func value(for flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag),
                  arguments.index(after: index) < arguments.endIndex
            else { return nil }
            return arguments[arguments.index(after: index)]
        }

        let section = value(for: "--section").flatMap(GallerySection.init(rawValue:))
            ?? .glass
        let scheme: ColorScheme? = switch value(for: "--scheme") {
        case "dark": .dark
        case "light": .light
        default: .dark
        }
        let opacity = value(for: "--opacity").flatMap(Double.init).map { min(max($0, 0), 1) }
            ?? 0.45

        if let scheme {
            window.appearance = NSAppearance(
                named: scheme == .dark ? .vibrantDark : .vibrantLight)
        }

        ShadcnGalleryWindow.install(
            ShadcnAIGallery(
                initialSection: section,
                scheme: scheme,
                surfaceOpacity: opacity),
            in: window
        )
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

let app = NSApplication.shared
let delegate = DemoAppDelegate()
app.delegate = delegate
app.run()
