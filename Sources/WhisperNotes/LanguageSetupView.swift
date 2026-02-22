import SwiftUI

public struct LanguageSetupView: View {
    @EnvironmentObject var state: AppState
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    public init() {}

    private var filteredLanguages: [SupportedLanguage] {
        guard !searchText.isEmpty else { return SupportedLanguage.all }
        let q = searchText.lowercased()
        return SupportedLanguage.all.filter {
            $0.name.lowercased().contains(q) || $0.code.lowercased().contains(q)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)
                    .padding(.top, 32)

                Text("Welcome to WhisperNotes")
                    .font(.title.bold())

                Text("Choose your primary transcription language.\nYou can change this later in Settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 20)

            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
                TextField("Search languages...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.callout)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.secondary.opacity(0.1))
            )
            .padding(.horizontal, 32)

            // Language list
            List(filteredLanguages) { lang in
                HStack {
                    Text(lang.name)
                    Spacer()
                    Text(lang.code)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if state.language == lang.code {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    state.language = lang.code
                }
            }
            .listStyle(.plain)
            .frame(maxHeight: 260)
            .padding(.top, 12)

            // Selected language indicator
            HStack {
                Text("Selected:")
                    .foregroundStyle(.secondary)
                Text(SupportedLanguage.named(state.language)?.name ?? state.language)
                    .fontWeight(.medium)
            }
            .font(.callout)
            .padding(.vertical, 8)

            // Continue button
            Button {
                state.completeSetup()
                dismiss()
            } label: {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .frame(width: 440, height: 560)
    }
}
