//
//  Context.swift
//  Segment
//
//  Created by Brandon Sneed on 2/23/21.
//

import Foundation

public class Context: PlatformPlugin {
    public let type: PluginType = .before
    public var analytics: Analytics?
    
    internal var staticContext = staticContextData()
    internal static var device = VendorSystem.current
    
    public func execute<T: RawEvent>(event: T?) -> T? {
        guard var workingEvent = event else { return event }
        
        var context = staticContext
        
        insertDynamicPlatformContextData(context: &context)
        
        // if this event came in with context data already
        // let it take precedence over our values.
        if let eventContext = workingEvent.context?.dictionaryValue {
            context.merge(eventContext) { (_, new) in new }
        }
        
        do {
            workingEvent.context = try JSON(context)
        } catch {
            exceptionFailure("Unable to convert context to JSON: \(error)")
        }
        
        return workingEvent
    }
    
    internal static func staticContextData() -> [String: Any] {
        var staticContext = [String: Any]()
        
        // library name
        staticContext["library"] = [
            "name": "analytics-swift",
            "version": __segment_version
        ]
        
        // overwrite ip
        staticContext["ip"] = "0.0.0.0"

        // app info
        let info = Bundle.main.infoDictionary
        let localizedInfo = Bundle.main.localizedInfoDictionary
        var app = [String: Any]()
        if let info = info {
            app.merge(info) { (_, new) in new }
        }
        if let localizedInfo = localizedInfo {
            app.merge(localizedInfo) { (_, new) in new }
        }
        if app.count != 0 {
            staticContext["app"] = [
                "name": app["CFBundleDisplayName"] ?? "",
                "version": app["CFBundleShortVersionString"] ?? "",
                "build": app["CFBundleVersion"] ?? "",
                "namespace": Bundle.main.bundleIdentifier ?? ""
            ]
        }
        
        insertStaticPlatformContextData(context: &staticContext)
        
        return staticContext
    }
    
    internal static func insertStaticPlatformContextData(context: inout [String: Any]) {
        // device
        let device = Self.device
        let memoryGB = ProcessInfo.processInfo.physicalMemory / (1024*1024*1024)
        let modelName = CurrentDevice.getModel()
        
        // "token" handled in DeviceToken.swift
        context["device"] = [
            "manufacturer": device.manufacturer,
            "type": device.type,
            "model": device.model, // eg arm, x86
            "physicalMemoryGB": memoryGB,
            "modelName": modelName // eg MacBookAir13,1
        ]
        // os
        context["os"] = [
            "name": device.systemName,
            "version": device.systemVersion
        ]
        // screen
        let screen = device.screenSize
        context["screen"] = [
            "width": screen.width,
            "height": screen.height
        ]
        // locale
        if Locale.preferredLanguages.count > 0 {
            context["locale"] = Locale.preferredLanguages[0]
        }
        // timezone
        context["timezone"] = TimeZone.current.identifier
    }

    internal func insertDynamicPlatformContextData(context: inout [String: Any]) {
        let device = Self.device
        
        // network
        let status = device.connection
        
        var cellular = false
        var wifi = false
        var bluetooth = false
        
        switch status {
        case .online(.cellular):
            cellular = true
        case .online(.wifi):
            wifi = true
        case .online(.bluetooth):
            bluetooth = true
        default:
            break
        }
        
        // network connectivity
        context["network"] = [
            "bluetooth": bluetooth, // not sure any swift platforms support this currently
            "cellular": cellular,
            "wifi": wifi
        ]
        
        // other stuff?? ...
    }

}

enum CurrentDevice {
    /// Returns the model identifier for the current device.
    /// (i.e. MacbookPro18,1)
    static func getModel() -> String {
        // swiftlint:disable force_unwrapping
        #if canImport(UIKit)
        // taken from https://github.com/Ekhoo/Device/blob/master/Source/iOS/Device.swift#LL17C138-L17C138
        var systemInfo = utsname()
        uname(&systemInfo)
        return String(
            validatingUTF8: NSString(
                bytes: &systemInfo.machine,
                length: Int(_SYS_NAMELEN),
                encoding: String.Encoding.ascii.rawValue
            )!.utf8String!
        )!
        #else
        // h/t Saleem!
        // https://thebrowsercompany.slack.com/archives/C0322NP6800/p1682960559345599?thread_ts=1682959159.259779&cid=C0322NP6800
        var len: CLong = 0
        _ = sysctlbyname("hw.model", nil, &len, nil, 0)
        return withUnsafeTemporaryAllocation(of: CChar.self, capacity: len) {
            _ = sysctlbyname("hw.model", $0.baseAddress!, &len, nil, 0)
            return String(cString: $0.baseAddress!)
        }
        #endif
        // swiftlint:enable force_unwrapping
    }
}
