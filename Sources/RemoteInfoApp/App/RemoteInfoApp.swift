import AppKit
import RemoteInfoCore
import SwiftUI

@main
struct RemoteInfoApp: App {
    @StateObject private var store: TelemetryStore
    private let configurationError: String?
    private let refreshEnabled: Bool
    private let isMockMode: Bool

    init() {
        let bootstrap = TelemetryBootstrapper.bootstrap()
        _store = StateObject(wrappedValue: bootstrap.store)
        configurationError = bootstrap.configurationError
        refreshEnabled = bootstrap.refreshEnabled
        isMockMode = bootstrap.isMockMode

        if bootstrap.refreshEnabled {
            Task { @MainActor in
                await bootstrap.store.refreshAll()
                bootstrap.store.startPeriodicRefresh()
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanelView(
                store: store,
                configurationError: configurationError,
                refreshEnabled: refreshEnabled,
                isMockMode: isMockMode
            )
        } label: {
            Image(nsImage: StatusMenuIcon.image)
                .resizable()
                .frame(width: 18, height: 18)
        }
        .menuBarExtraStyle(.window)
    }
}

private enum StatusMenuIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()

        NSGraphicsContext.current?.shouldAntialias = true
        NSColor.black.setStroke()
        NSColor.black.setFill()

        let head = NSBezierPath()
        head.move(to: NSPoint(x: 9, y: 2.5))
        head.curve(
            to: NSPoint(x: 2.8, y: 8.3),
            controlPoint1: NSPoint(x: 5.3, y: 2.5),
            controlPoint2: NSPoint(x: 2.8, y: 5.1)
        )
        head.curve(
            to: NSPoint(x: 3.9, y: 14.4),
            controlPoint1: NSPoint(x: 2.8, y: 10.6),
            controlPoint2: NSPoint(x: 3.2, y: 12.6)
        )
        head.curve(
            to: NSPoint(x: 6.9, y: 12.8),
            controlPoint1: NSPoint(x: 4.8, y: 13.4),
            controlPoint2: NSPoint(x: 5.8, y: 12.9)
        )
        head.curve(
            to: NSPoint(x: 9, y: 13.4),
            controlPoint1: NSPoint(x: 7.7, y: 13.2),
            controlPoint2: NSPoint(x: 8.3, y: 13.4)
        )
        head.curve(
            to: NSPoint(x: 11.1, y: 12.8),
            controlPoint1: NSPoint(x: 9.7, y: 13.4),
            controlPoint2: NSPoint(x: 10.3, y: 13.2)
        )
        head.curve(
            to: NSPoint(x: 14.1, y: 14.4),
            controlPoint1: NSPoint(x: 12.2, y: 12.9),
            controlPoint2: NSPoint(x: 13.2, y: 13.4)
        )
        head.curve(
            to: NSPoint(x: 15.2, y: 8.3),
            controlPoint1: NSPoint(x: 14.8, y: 12.6),
            controlPoint2: NSPoint(x: 15.2, y: 10.6)
        )
        head.curve(
            to: NSPoint(x: 9, y: 2.5),
            controlPoint1: NSPoint(x: 15.2, y: 5.1),
            controlPoint2: NSPoint(x: 12.7, y: 2.5)
        )
        head.lineWidth = 1.45
        head.lineJoinStyle = .round
        head.stroke()

        NSBezierPath(ovalIn: NSRect(x: 5.2, y: 8.1, width: 2.2, height: 2.2)).fill()
        NSBezierPath(ovalIn: NSRect(x: 10.6, y: 8.1, width: 2.2, height: 2.2)).fill()

        let beak = NSBezierPath()
        beak.move(to: NSPoint(x: 9, y: 6.1))
        beak.line(to: NSPoint(x: 7.9, y: 7.5))
        beak.line(to: NSPoint(x: 10.1, y: 7.5))
        beak.close()
        beak.fill()

        let telemetry = NSBezierPath()
        telemetry.move(to: NSPoint(x: 6.3, y: 4.3))
        telemetry.line(to: NSPoint(x: 11.7, y: 4.3))
        telemetry.move(to: NSPoint(x: 7.2, y: 3.4))
        telemetry.line(to: NSPoint(x: 10.8, y: 3.4))
        telemetry.lineWidth = 1.2
        telemetry.lineCapStyle = .round
        telemetry.stroke()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }()
}
