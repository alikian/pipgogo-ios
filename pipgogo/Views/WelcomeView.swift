import SwiftUI

struct WelcomeView: View {
    let isBusy: Bool
    let errorMessage: String?
    let signIn: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.indigo.opacity(0.18), Color.cyan.opacity(0.08), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                Image(systemName: "airplane.departure")
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(.indigo)
                    .accessibilityHidden(true)
                VStack(spacing: 10) {
                    Text("PipGoGo")
                        .font(.largeTitle.bold())
                    Text("A thoughtful travel companion for the journey ahead.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
                if let errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .accessibilityLabel("Sign-in error: \(errorMessage)")
                }
                Button(action: signIn) {
                    HStack(spacing: 12) {
                        if isBusy { ProgressView().tint(.white) }
                        Image(systemName: "person.crop.circle.badge.checkmark")
                        Text(isBusy ? "Connecting…" : "Continue with Google")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .disabled(isBusy)
                Text("Sign-in is securely handled by Google and Amazon Cognito.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
        }
    }
}
