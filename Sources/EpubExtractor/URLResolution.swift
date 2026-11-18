import Foundation

extension URL {
    /// Resolves an EPUB href (percent-encoded, optionally with a `#fragment`) against this directory URL.
    /// `appendingPathComponent` alone would encode the `#` into the file name.
    func resolvingEpubHref(_ href: String) -> URL {
        let parts = href.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        let rawPath = String(parts.first ?? "")
        let path = rawPath.removingPercentEncoding ?? rawPath
        let base = URL(fileURLWithPath: appendingPathComponent(path).path).standardizedFileURL

        guard parts.count == 2, !parts[1].isEmpty,
              var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return base
        }
        components.fragment = String(parts[1])
        return components.url ?? base
    }
}
