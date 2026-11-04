import LocalAuthentication
import SwiftUI
import UIKit

/// Wraps the app so `AppLock` hears about scene changes.
struct LockGate<Content: View>: View {
    @ViewBuilder var content: Content

    @AppStorage(SettingsKey.requireFaceID) private var requireFaceID = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        content
            .onChange(of: scenePhase, initial: true) {
                AppLock.shared.sceneChanged(to: scenePhase, requireFaceID: requireFaceID)
            }
            .onChange(of: requireFaceID) {
                AppLock.shared.sceneChanged(to: scenePhase, requireFaceID: requireFaceID)
            }
    }
}

/// Privacy for the app's screens:
/// - **App switcher / Control Center:** whenever the app isn't active, a cover hides its
///   contents, so earnings and maps don't show in the app switcher snapshot.
/// - **Face ID lock (optional):** when the app comes back, it stays covered until Face ID
///   (or the passcode) succeeds.
///
/// The cover is a separate window above everything, so open sheets are covered too, and
/// the app's own windows are hidden from VoiceOver while locked.
@MainActor
final class AppLock {
    static let shared = AppLock()

    private var unlocked = false
    private var authenticating = false
    private var overlay: UIWindow?

    /// Whether the phone has Face ID, Touch ID or a passcode that can protect the app.
    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    func sceneChanged(to phase: ScenePhase, requireFaceID: Bool) {
        switch phase {
        case .background:
            unlocked = false
            showOverlay(locked: requireFaceID)
        case .inactive:
            showOverlay(locked: requireFaceID && !unlocked)
        case .active:
            if requireFaceID && !unlocked {
                showOverlay(locked: true)
                authenticate()
            } else {
                hideOverlay()
            }
        @unknown default:
            break
        }
    }

    /// Asks for Face ID / passcode once, e.g. before turning the lock on in Settings.
    func confirmOwner(reason: String, completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            completion(false)
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
            Task { @MainActor in
                if success { self.unlocked = true }
                completion(success)
            }
        }
    }

    private func authenticate() {
        guard !authenticating else { return }
        guard Self.isAvailable else {
            // No passcode on the phone: the lock can't work, so don't shut the user out.
            unlocked = true
            hideOverlay()
            return
        }
        authenticating = true
        confirmOwner(reason: "Unlock your gig log") { success in
            self.authenticating = false
            guard success else { return }
            if UIApplication.shared.applicationState == .active {
                self.hideOverlay()
            } else {
                self.showOverlay(locked: false)
            }
        }
    }

    // MARK: - Overlay window

    private func showOverlay(locked: Bool) {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        let window = overlay ?? {
            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert + 1
            overlay = window
            return window
        }()
        let host = UIHostingController(rootView: LockOverlayView(locked: locked) { [weak self] in
            self?.authenticate()
        })
        host.view.backgroundColor = .systemBackground
        window.rootViewController = host
        window.isHidden = false
        setAppWindowsHiddenFromAccessibility(locked, in: scene)
    }

    private func hideOverlay() {
        guard let overlay else { return }
        overlay.isHidden = true
        overlay.rootViewController = nil
        if let scene = overlay.windowScene {
            setAppWindowsHiddenFromAccessibility(false, in: scene)
        }
    }

    private func setAppWindowsHiddenFromAccessibility(_ hidden: Bool, in scene: UIWindowScene) {
        for window in scene.windows where window !== overlay {
            window.accessibilityElementsHidden = hidden
        }
    }
}

/// The cover shown in the app switcher (`locked == false`) or while waiting for Face ID.
struct LockOverlayView: View {
    let locked: Bool
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: locked ? "lock.fill" : "car.fill")
                .font(.system(size: 44))
                .foregroundStyle(locked ? Color.primary : Color.accentColor)
            Text(locked ? "Gig Log is locked" : "Gig Log")
                .font(.title2.bold())
            if locked {
                Button("Unlock", action: onUnlock)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}
