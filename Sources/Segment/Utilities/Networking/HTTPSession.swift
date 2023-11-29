import Foundation

#if os(Linux) || os(Windows)
import FoundationNetworking
#endif

public protocol DataTask {
  var state: URLSessionTask.State { get }
  func resume()
}

// An enumeration of default `HTTPSession` configurations to be used
// This can be extended buy consumer to easily refer back to their configured session.
public enum DefaultHTTPSession {
  static let urlSession: HTTPSession = {
      let configuration = URLSessionConfiguration.ephemeral
      configuration.httpMaximumConnectionsPerHost = 2
      let session = URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
      return session
  }()
}

public protocol HTTPSession {
  func uploadTask(with request: URLRequest, fromFile file: URL, completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> DataTask
  func dataTask(with request: URLRequest, completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> DataTask
  func finishTasksAndInvalidate()
}
