import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = GameCatalogViewModel()

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                SidebarView(viewModel: viewModel)

                Divider()

                // Right Primary Canvas Dashboard Interface
                Group {
                    if viewModel.isLoading {
                        ProgressView() {
                            Text("Ingesting master node clusters...")
                                .font(.caption)
                                .monospaced()
                        }
                    } else if let error = viewModel.errorMessage {
                        ContentUnavailableView {
                            Label("Sync failure", systemImage: "exclamationmark.triangle.fill")
                        } description: {
                            Text(error)
                        } actions: {
                            Button("Retry") {
                                Task { await viewModel.loadCatalog() }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else if viewModel.games.isEmpty {
                        ContentUnavailableView(
                            "Empty Terminal",
                            systemImage: "tray",
                            description: Text("No operational server instances located.")
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 14) {
                                ForEach(viewModel.sortedGames) { game in
                                    NavigationLink(value: game) {
                                        GameCardRowView(game: game)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.all, 20)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.green))
            }
            // Each game gets its own dedicated page
            .navigationDestination(for: GameItem.self) { game in
                GameDetailView(game: game)
            }
        }
        .task { await viewModel.loadCatalog() }
    }
}

// MARK: - Left App Dashboard Control Panel Sidebar Area
struct SidebarView: View {
    @ObservedObject var viewModel: GameCatalogViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("OPE")
                .font(.system(.title3, design: .monospaced))
                .bold()
                .italic()
                .kerning(4)
                .padding(.top, 24)

            Button(action: {
                Task { await viewModel.loadCatalog() }
            }) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .imageScale(.large)
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Refresh Inventory")

            Button(action: {
                viewModel.toggleSortOrder()
            }) {
                Image(systemName: viewModel.sortAscending ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .imageScale(.large)
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Toggle Sort Order")

            if let siteURL = URL(string: "https://theothegooddog.github.io/ope/api/games") {
                Link(destination: siteURL) {
                    Image(systemName: "globe")
                        .imageScale(.large)
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                .accessibilityLabel("Open Master Inventory in Browser")
            }

            Spacer()

            Text("\(viewModel.games.count)")
                .font(.caption2.monospaced())
                .foregroundColor(.secondary)
                .padding(.bottom, 16)
                .accessibilityLabel("\(viewModel.games.count) games loaded")
        }
        .frame(width: 80)
        .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.vertical))
    }
}

// MARK: - Elegant Modular Row View Architecture
struct GameCardRowView: View {
    let game: GameItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(game.gameTitle)
                        .font(.headline)
                        .bold()
                        .foregroundColor(.primary)

                    Text("Directory: \(game.folderPath)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("v\(game.buildIndex)")
                    .font(.caption2.monospaced())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(.accentColor)
                    .clipShape(Capsule())
            }

            HStack {
                if let targetURL = game.fullAPIURL {
                    HStack(spacing: 6) {
                        Image(systemName: "terminal.fill")
                        Text(targetURL.absoluteString)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .font(.caption2.monospaced())
                    .foregroundColor(.blue)
                }

                Spacer()

                JoinButton(game: game, compact: true)

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }
        }
        .padding(.all, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        )
    }
}

// MARK: - Yellow Join Button
struct JoinButton: View {
    let game: GameItem
    var compact = false

    @Environment(\.openURL) private var openURL

    var body: some View {
        Button(action: {
            guard let url = game.fullAPIURL else { return }
            openURL(url)
        }) {
            HStack(spacing: 6) {
                Image(systemName: "play.fill")
                Text(compact ? "Join" : "Join Game")
            }
            .font(compact ? .caption.bold() : .headline.bold())
            .foregroundColor(.black)
            .padding(.horizontal, compact ? 12 : 24)
            .padding(.vertical, compact ? 6 : 12)
            .frame(maxWidth: compact ? nil : .infinity)
            .background(Color.yellow)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Join \(game.gameTitle)")
    }
}
