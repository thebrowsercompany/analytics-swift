import Foundation

#if os(Windows)

import WinSDK

class WindowsVendorSystem: VendorSystem {
  override var manufacturer: String {
    return "unknown"
  }

  override var type: String {
    return "Windows"
  }

  override var model: String {
    return "unknown"
  }

  override var name: String {
    return "unknown"
  }

  override var identifierForVendor: String? {
    return nil
  }

  override var systemName: String {
    return "Windows"
  }

  override var systemVersion: String {
    let info = ProcessInfo.processInfo.operatingSystemVersion
    return "\(info.majorVersion).\(info.minorVersion).\(info.patchVersion)"
  }

  override var screenSize: ScreenSize {
    return ScreenSize(width: 0, height: 0)
  }

  override var userAgent: String? {
    return nil
  }

  override var connection: ConnectionStatus {
    return ConnectionStatus.unknown
  }

  override var requiredPlugins: [any PlatformPlugin] {
    return []
  }
}

#endif
