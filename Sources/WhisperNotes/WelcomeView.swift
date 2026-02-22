import SwiftUI

struct WelcomeFeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(iconColor)
                .frame(width: 40, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct WelcomeView: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 40)

            // App icon
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            // Title
            Text("Welcome to WhisperNotes")
                .font(.largeTitle.bold())
                .padding(.top, 16)

            Text("Record, transcribe, and organize\nyour audio notes with ease.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)

            // Feature rows
            VStack(alignment: .leading, spacing: 20) {
                WelcomeFeatureRow(
                    icon: "mic.fill",
                    iconColor: .red,
                    title: "Record & Transcribe",
                    description: "Capture audio and get instant transcriptions powered by Whisper AI."
                )

                WelcomeFeatureRow(
                    icon: "folder.fill",
                    iconColor: .blue,
                    title: "Organize with Folders & Tags",
                    description: "Keep your notes tidy with custom folders and color-coded tags."
                )

                WelcomeFeatureRow(
                    icon: "doc.text.fill",
                    iconColor: .green,
                    title: "Markdown Sync",
                    description: "Notes auto-save as Markdown files to your Documents folder."
                )

                WelcomeFeatureRow(
                    icon: "command",
                    iconColor: .orange,
                    title: "Keyboard Shortcuts",
                    description: "Cmd+N to record, Cmd+F to search, Cmd+D to favorite, and more."
                )
            }
            .padding(.horizontal, 40)
            .padding(.top, 32)

            Spacer()

            // Continue button
            Button {
                onContinue()
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .padding(.horizontal, 40)
            .padding(.bottom, 28)
            .accessibilityHint("Proceed to language selection")
        }
        .frame(width: 440, height: 560)
    }
}
