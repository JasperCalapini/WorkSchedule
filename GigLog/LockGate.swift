import SwiftUI
import LocalAuthentication

/// Covers the app with a lock screen when "Require Face ID" is on, and asks for
/// Face ID (or the passcode) when the app opens or comes back from the background.
struct LockGate<Content: View>: View {
    @ViewBuilder var content: Content

    @AppStorage("requireFaceID") private var requireFaceID = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var unlocked = false
    @State private var authenticating = false

    var body: some View {
        ZStack {
            content
            if requireFaceID && !unlocked {
                lockScreen
            }
        }
        .onChange(of: scenePhase) {
            switch scenePhase {
            case .background: unlocked = false
            case .active: if requireFaceID && !unlocked { authenticate() }
            default: break
            }
        }
        .onAppear { if requireFaceID { authenticate() } }
    }

    private var lockScreen: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill").font(.system(size: 44))
            Text("Gig Log is locked").font(.title2.bold())
            Button("Unlock", action: authenticate)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    private func authenticate() {
        guard !authenticating else { return }
        let context = LAContext()
        var error: NSError?
        // Falls back to the device passcode if Face ID isn't available.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            unlocked = true
            return
        }
        authenticating = true
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your gig log") { success, _ in
            Task { @MainActor in
                authenticating = false
                if success { unlocked = true }
            }
        }
    }
}
