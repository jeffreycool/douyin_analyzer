import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Set minimum window size
    self.minSize = NSSize(width: 800, height: 600)

    // Set default window size and center
    let screenFrame = NSScreen.main?.visibleFrame ?? NSRect.zero
    let defaultWidth: CGFloat = 960
    let defaultHeight: CGFloat = 720
    let originX = (screenFrame.width - defaultWidth) / 2 + screenFrame.origin.x
    let originY = (screenFrame.height - defaultHeight) / 2 + screenFrame.origin.y
    self.setFrame(NSRect(x: originX, y: originY, width: defaultWidth, height: defaultHeight), display: true)

    // Window style
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
