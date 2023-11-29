import Foundation

#if os(Linux) || os(Windows)
import FoundationNetworking
#endif

extension URLSessionDataTask: DataTask {}

// Give the built in `URLSession` conformance to HTTPSession so that it can easily be used
extension URLSession: HTTPSession {
  public func uploadTask(with request: URLRequest, fromFile file: URL, completionHandler: @escaping (Data?, URLResponse?,  (any Error)?) -> Void) -> any DataTask {
      let task: URLSessionUploadTask = uploadTask(with: request, fromFile: file, completionHandler: completionHandler)

      return task
  }

  public func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, (any Error)?) -> Void) -> any DataTask {
    let task: URLSessionDataTask = dataTask(with: request, completionHandler: completionHandler)

    return task
  }
}
