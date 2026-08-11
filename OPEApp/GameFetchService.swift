import Foundation

// MARK: - Game Item Model
public struct GameItem: Identifiable, Hashable {
    public let id = UUID()
    public let gameTitle: String
    public let folderPath: String
    public let buildIndex: String
    public let rawPath: String

    /// The scripts live flat in /ope/api/ keyed by build index,
    /// e.g. https://theothegooddog.github.io/ope/api/1.py
    public var fullAPIURL: URL? {
        URL(string: "https://theothegooddog.github.io/ope/api/\(buildIndex).py")
    }
}

// MARK: - API Network Layer
public protocol GameFetchServiceProtocol {
    func fetchAndParseMasterInventory() async throws -> [GameItem]
    func fetchScriptSource(for game: GameItem) async throws -> String
}

public final class GameFetchService: GameFetchServiceProtocol {
    private let session: URLSession
    private let targetURLString = "https://theothegooddog.github.io/ope/api/games"

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetchAndParseMasterInventory() async throws -> [GameItem] {
        guard let url = URL(string: targetURLString) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        guard let rawString = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "ParsingError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Malformed data payload encoding"])
        }

        return parseParenthesesFormat(from: rawString)
    }

    /// Downloads the raw python source for a single game entry.
    public func fetchScriptSource(for game: GameItem) async throws -> String {
        guard let url = game.fullAPIURL else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        guard let source = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "ParsingError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Script payload is not valid UTF-8"])
        }

        return source
    }

    /// Parses patterns like "(Default Game/Default Game for OPE/1)" safely.
    private func parseParenthesesFormat(from text: String) -> [GameItem] {
        // Matches anything wrapped inside parentheses securely
        let pattern = "\\(([^)]+)\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: range)

        return matches.compactMap { match -> GameItem? in
            guard let targetRange = Range(match.range(at: 1), in: text) else { return nil }
            let rawContent = String(text[targetRange])

            // Components split by forward slash separator mapping to properties
            let segments = rawContent.components(separatedBy: "/")
            guard segments.count >= 3 else {
                // Fallback graceful initialization if the item pattern is non-standard
                return GameItem(gameTitle: rawContent, folderPath: "Unknown", buildIndex: "0", rawPath: rawContent)
            }

            return GameItem(
                gameTitle: segments[0].trimmingCharacters(in: .whitespacesAndNewlines),
                folderPath: segments[1].trimmingCharacters(in: .whitespacesAndNewlines),
                buildIndex: segments[2].trimmingCharacters(in: .whitespacesAndNewlines),
                rawPath: rawContent
            )
        }
    }
}
