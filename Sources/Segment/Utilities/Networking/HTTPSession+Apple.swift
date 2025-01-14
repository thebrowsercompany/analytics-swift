import Foundation

#if os(Linux) || os(Windows)
import FoundationNetworking
#endif

extension URLSessionDataTask: DataTask {
  public func isRunning() -> Bool {
    state == .running
  }
}
extension URLSessionUploadTask: UploadTask {}

// Give the built in `URLSession` conformance to HTTPSession so that it can easily be used
extension URLSession: HTTPSession {}
