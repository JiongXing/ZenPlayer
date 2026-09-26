import AppKit

/// 仅用于临时验证 App 中的输入诊断，不含 ZenPlayer 搜索、解析或 SwiftUI Binding。
@MainActor
enum MacNativeInputProbe {
    private static var probeWindow: NSWindow?

    static func present(relativeTo window: NSWindow) {
        let frame = NSRect(x: window.frame.minX + 100, y: window.frame.maxY - 250, width: 500, height: 160)
        let probe = NSWindow(contentRect: frame, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        probe.title = "Native Input Validation"
        probe.isReleasedWhenClosed = false
        let field = NSTextField(frame: NSRect(x: 24, y: 60, width: 452, height: 28))
        field.placeholderString = "Native XCTest Input"
        field.isAutomaticTextCompletionEnabled = false
        field.setAccessibilityIdentifier("nativeInputProbeField")
        probe.contentView?.addSubview(field)
        probeWindow = probe
        probe.makeKeyAndOrderFront(nil)
        probe.makeFirstResponder(field)
    }
}
