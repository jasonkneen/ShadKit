import AIElementsGallery
import AppKit
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
        window.titlebarAppearsTransparent = true
        // `ShadKitDemo --section aiTemplates --scheme dark` opens straight
        // onto a page, which is what the screenshot pass drives.
        let arguments = CommandLine.arguments
        func value(for flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag),
                  arguments.index(after: index) < arguments.endIndex
            else { return nil }
            return arguments[arguments.index(after: index)]
        }

        let section = value(for: "--section").flatMap(GallerySection.init(rawValue:))
            ?? .aiConversation
        let scheme: ColorScheme? = switch value(for: "--scheme") {
        case "dark": .dark
        case "light": .light
        default: nil
        }

        // Keep AppKit's appearance in step with the forced scheme, so
        // system-drawn chrome (titlebar, scrollers, selection) matches the
        // palette rather than following the OS setting.
        if let scheme {
            window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        }

        window.contentView = NSHostingView(
            rootView: ShadcnAIGallery(initialSection: section, scheme: scheme)
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
