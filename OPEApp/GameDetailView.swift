import SwiftUI

// MARK: - Dedicated Page Per Game
struct GameDetailView: View {
    let game: GameItem

    @State private var scriptSource: String?
    @State private var isLoadingSource = false
    @State private var sourceError: String?
    @State private var didCopyURL = false

    private let service: GameFetchServiceProtocol = GameFetchService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                JoinButton(game: game)

                actionRow

                sourceSection
            }
            .padding(20)
        }
        .navigationTitle(game.gameTitle)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .task { await loadSource() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(game.gameTitle)
                        .font(.largeTitle)
                        .bold()

                    Text("Directory: \(game.folderPath)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("v\(game.buildIndex)")
                    .font(.caption.monospaced())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(.accentColor)
                    .clipShape(Capsule())
            }

            if let url = game.fullAPIURL {
                HStack(spacing: 6) {
                    Image(systemName: "terminal.fill")
                    Text(url.absoluteString)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .font(.caption2.monospaced())
                .foregroundColor(.blue)
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button(action: copyScriptURL) {
                Label(didCopyURL ? "Copied!" : "Copy URL", systemImage: didCopyURL ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.bordered)

            if let url = game.fullAPIURL {
                Link(destination: url) {
                    Label("Open in Browser", systemImage: "safari")
                }
                .buttonStyle(.bordered)
            }

            Button(action: {
                Task { await loadSource() }
            }) {
                Label("Reload Source", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .font(.caption)
    }

    @ViewBuilder
    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SCRIPT SOURCE")
                .font(.caption2.monospaced())
                .kerning(2)
                .foregroundColor(.secondary)

            if isLoadingSource {
                ProgressView() {
                    Text("Downloading script payload...")
                        .font(.caption)
                        .monospaced()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if let sourceError {
                ContentUnavailableView(
                    "Source unavailable",
                    systemImage: "exclamationmark.triangle.fill",
                    description: Text(sourceError)
                )
            } else if let scriptSource {
                ScrollView(.horizontal) {
                    Text(scriptSource)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }
        }
    }

    private func copyScriptURL() {
        guard let url = game.fullAPIURL else { return }
        UIPasteboard.general.string = url.absoluteString
        didCopyURL = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            didCopyURL = false
        }
    }

    private func loadSource() async {
        isLoadingSource = true
        sourceError = nil

        do {
            scriptSource = try await service.fetchScriptSource(for: game)
        } catch {
            sourceError = error.localizedDescription
        }

        isLoadingSource = false
    }
}
