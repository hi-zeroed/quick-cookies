import Foundation
import ImageIO
import WebKit
import UniformTypeIdentifiers

enum MarkdownImageProbe {
    // Image metadata probing stays in pure Swift so Markdown preparation does
    // not need an off-screen WKWebView just to learn intrinsic asset sizes.
    static func probeImages(in markdown: String, baseDirectoryURL: URL?) -> [MarkdownImageMeta] {
        let sources = extractSources(in: markdown)
        var seen = Set<String>()
        var metas: [MarkdownImageMeta] = []

        for source in sources where !source.isEmpty && !seen.contains(source) {
            seen.insert(source)
            let resolvedURL = resolveSourceURL(rawSource: source, relativeTo: baseDirectoryURL)

            if let resolvedURL,
               resolvedURL.isFileURL,
               let imageSource = CGImageSourceCreateWithURL(resolvedURL as CFURL, nil),
               let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] {
                let width = properties[kCGImagePropertyPixelWidth] as? Int
                let height = properties[kCGImagePropertyPixelHeight] as? Int
                metas.append(
                    MarkdownImageMeta(
                        source: source,
                        resolvedSourceURL: PreviewLocalResourceSchemeMapper.webViewURLString(for: resolvedURL),
                        width: width,
                        height: height
                    )
                )
            } else {
                metas.append(
                    MarkdownImageMeta(
                        source: source,
                        resolvedSourceURL: resolvedURL.flatMap(PreviewLocalResourceSchemeMapper.webViewURLString(for:)),
                        width: nil,
                        height: nil
                    )
                )
            }
        }

        return metas
    }

    private static func extractSources(in markdown: String) -> [String] {
        var sources: [String] = []
        let markdownImagePattern = #"!\[[^\]]*\]\((?:<([^>]+)>|([^) \t]+))(?:\s+"[^"]*")?\)"#
        let htmlImagePattern = #"<img\s+[^>]*src=['"]([^'"]+)['"][^>]*>"#

        sources.append(contentsOf: matches(in: markdown, pattern: markdownImagePattern))
        sources.append(contentsOf: matches(in: markdown, pattern: htmlImagePattern, options: [.caseInsensitive]))
        return sources
    }

    private static func matches(
        in text: String,
        pattern: String,
        options: NSRegularExpression.Options = []
    ) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return []
        }

        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, options: [], range: range).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }

            for groupIndex in 1..<match.numberOfRanges {
                guard match.range(at: groupIndex).location != NSNotFound,
                      let sourceRange = Range(match.range(at: groupIndex), in: text) else {
                    continue
                }
                return String(text[sourceRange])
            }

            return nil
        }
    }

    private static func resolveSourceURL(rawSource: String, relativeTo baseDirectoryURL: URL?) -> URL? {
        let trimmed = rawSource.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let absoluteURL = URL(string: trimmed), absoluteURL.scheme != nil {
            return absoluteURL
        }

        if trimmed.hasPrefix("/") {
            return URL(fileURLWithPath: trimmed)
        }

        guard let baseDirectoryURL else { return nil }
        return URL(fileURLWithPath: trimmed, relativeTo: baseDirectoryURL).standardizedFileURL
    }
}

enum PreviewLocalResourceSchemeMapper {
    static let scheme = "quickcookies-local"

    static func webViewURLString(for fileURL: URL) -> String? {
        guard fileURL.isFileURL else { return nil }

        var components = URLComponents()
        components.scheme = scheme
        components.host = "asset"
        components.queryItems = [
            URLQueryItem(name: "path", value: fileURL.path)
        ]
        return components.url?.absoluteString
    }

    static func fileURL(from url: URL) -> URL? {
        guard url.scheme == scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let path = components.queryItems?.first(where: { $0.name == "path" })?.value,
              !path.isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: path)
    }
}

final class PreviewLocalResourceSchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let requestURL = urlSchemeTask.request.url,
              let fileURL = PreviewLocalResourceSchemeMapper.fileURL(from: requestURL) else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let response = URLResponse(
                url: requestURL,
                mimeType: mimeType(for: fileURL),
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            urlSchemeTask.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}

    private func mimeType(for fileURL: URL) -> String {
        guard let type = UTType(filenameExtension: fileURL.pathExtension),
              let mimeType = type.preferredMIMEType else {
            return "application/octet-stream"
        }
        return mimeType
    }
}

enum PreviewWebViewConfiguration {
    static func prepare(_ configuration: WKWebViewConfiguration) {
        // Shared rule for any WebView-backed preview shell:
        // - configure the shell once here instead of scattering per-feature
        //   WebKit setup across Markdown, future HTML previews, etc.
        // - local document assets should flow through our controlled scheme
        //   instead of depending on WKWebView's file-subresource behavior
        //   after JavaScript rewrites/incremental DOM updates
        // - future preview types that reuse the shared runtime should extend
        //   this configuration path before introducing another long-lived shell
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.websiteDataStore = .default()
        configuration.userContentController = WKUserContentController()
        configuration.setURLSchemeHandler(
            PreviewLocalResourceSchemeHandler(),
            forURLScheme: PreviewLocalResourceSchemeMapper.scheme
        )
    }
}
