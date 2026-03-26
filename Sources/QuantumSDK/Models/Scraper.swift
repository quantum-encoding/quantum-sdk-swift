import Foundation

// MARK: - Scrape

public struct ScrapeTarget: Codable, Sendable {
    public let name: String
    public let url: String
    public let type: String?
    public let selector: String?
    public let content: String?
    public let notebook: String?
    public let recursive: Bool?
    public let maxPages: Int?
    public let delayMs: Int?
    public let ingest: String?

    enum CodingKeys: String, CodingKey {
        case name, url, type, selector, content, notebook, recursive, ingest
        case maxPages = "max_pages"
        case delayMs = "delay_ms"
    }

    public init(name: String, url: String, type: String? = nil, selector: String? = nil,
                content: String? = nil, notebook: String? = nil, recursive: Bool? = nil,
                maxPages: Int? = nil, delayMs: Int? = nil, ingest: String? = nil) {
        self.name = name; self.url = url; self.type = type; self.selector = selector
        self.content = content; self.notebook = notebook; self.recursive = recursive
        self.maxPages = maxPages; self.delayMs = delayMs; self.ingest = ingest
    }
}

public struct ScrapeRequest: Codable, Sendable {
    public let targets: [ScrapeTarget]
    public init(targets: [ScrapeTarget]) { self.targets = targets }
}

public struct ScrapeResponse: Codable, Sendable {
    public let jobId: String
    public let status: String
    public let targets: Int
    public let requestId: String

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status, targets
        case requestId = "request_id"
    }
}

// MARK: - Screenshot

public struct ScreenshotURL: Codable, Sendable {
    public let url: String
    public let width: Int?
    public let height: Int?
    public let fullPage: Bool?
    public let delayMs: Int?

    enum CodingKeys: String, CodingKey {
        case url, width, height
        case fullPage = "full_page"
        case delayMs = "delay_ms"
    }

    public init(url: String, width: Int? = nil, height: Int? = nil,
                fullPage: Bool? = nil, delayMs: Int? = nil) {
        self.url = url; self.width = width; self.height = height
        self.fullPage = fullPage; self.delayMs = delayMs
    }
}

public struct ScreenshotRequest: Codable, Sendable {
    public let urls: [ScreenshotURL]
    public init(urls: [ScreenshotURL]) { self.urls = urls }
}

public struct ScreenshotResult: Codable, Sendable {
    public let url: String
    public let base64: String
    public let format: String
    public let width: Int
    public let height: Int
    public let error: String?
}

public struct ScreenshotResponse: Codable, Sendable {
    public let screenshots: [ScreenshotResult]
    public let count: Int
}
