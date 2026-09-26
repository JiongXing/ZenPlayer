import Foundation

/// 仅编入临时验证 App；保留真实 APIService 的请求、解码和错误路径。
nonisolated final class MacCatalogURLProtocol: URLProtocol {
    private static let categoryURL = "https://api.jingzong.net/jiangyan/v3/hz_video/category1?client=ios&v=3"

    override class func canInit(with request: URLRequest) -> Bool {
        let arguments = ProcessInfo.processInfo.arguments
        if request.url?.absoluteString == categoryURL {
            return arguments.contains("--stage-category-failure")
                || arguments.contains("--stage-seed-catalog")
                || arguments.contains("--stage-verify-catalog")
        }
        return request.url?.absoluteString == MacCatalogFixture.detailURL
            && (arguments.contains("--stage-seed-catalog") || arguments.contains("--stage-verify-catalog"))
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if request.url?.absoluteString == Self.categoryURL {
            client?.urlProtocol(self, didFailWithError: NSError(
                domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet,
                userInfo: [NSLocalizedDescriptionKey: "Mac 分類請求失敗驗證"]))
            return
        }
        do {
            let data = try MacCatalogFixture.responseData()
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1",
                                           headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() { }
}
