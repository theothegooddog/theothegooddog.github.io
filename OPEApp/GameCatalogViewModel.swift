import Foundation

@MainActor
public final class GameCatalogViewModel: ObservableObject {
    @Published public private(set) var games: [GameItem] = []
    @Published public private(set) var isLoading = false
    @Published public var errorMessage: String? = nil
    @Published public var sortAscending = true

    private let service: GameFetchServiceProtocol

    public init(service: GameFetchServiceProtocol = GameFetchService()) {
        self.service = service
    }

    public var sortedGames: [GameItem] {
        games.sorted {
            sortAscending
                ? $0.gameTitle.localizedCaseInsensitiveCompare($1.gameTitle) == .orderedAscending
                : $0.gameTitle.localizedCaseInsensitiveCompare($1.gameTitle) == .orderedDescending
        }
    }

    public func loadCatalog() async {
        isLoading = true
        errorMessage = nil

        do {
            let fetchedItems = try await service.fetchAndParseMasterInventory()
            self.games = fetchedItems
        } catch {
            self.errorMessage = error.localizedDescription
        }

        self.isLoading = false
    }

    public func toggleSortOrder() {
        sortAscending.toggle()
    }
}
