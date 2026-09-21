import Foundation
import AuthenticationServices
import Observation

struct SignInInfo {
    let displayName: String?
    let email: String?
}

@MainActor
@Observable
final class AuthService {
    enum State: Equatable {
        case checking
        case signedOut
        case signedIn(userID: String)
    }

    private(set) var state: State = .checking
    var errorMessage: String?

    /// Name/email from a brand-new authorization, handed to the profile layer once.
    @ObservationIgnored private var freshSignInInfo: SignInInfo?
    @ObservationIgnored private var revocationObserver: NSObjectProtocol?

    private static let userIDKey = "appleUserID"
    static let demoUserID = "demo-user"

    init() {
        // Apple posts this if the user revokes Hydrometer in Settings › Apple ID › Sign-In & Security.
        revocationObserver = NotificationCenter.default.addObserver(
            forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // queue: .main guarantees we're on the main thread here.
            MainActor.assumeIsolated {
                self?.signOut()
            }
        }
    }

    // MARK: Session restore

    func restoreSession() async {
        guard let userID = KeychainHelper.read(Self.userIDKey) else {
            state = .signedOut
            return
        }
        if userID == Self.demoUserID {
            state = .signedIn(userID: userID)
            return
        }

        switch await Self.credentialState(for: userID) {
        case .revoked?, .notFound?:
            signOut()
        default:
            // .authorized, .transferred, or nil (network error) → keep the local session.
            state = .signedIn(userID: userID)
        }
    }

    /// Wraps the completion-handler API; returns nil if Apple couldn't be reached.
    private static func credentialState(for userID: String) async -> ASAuthorizationAppleIDProvider.CredentialState? {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { credentialState, error in
                continuation.resume(returning: error == nil ? credentialState : nil)
            }
        }
    }

    // MARK: Sign in with Apple

    func configure(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Sign in returned an unexpected credential. Try again."
                return
            }
            let name = credential.fullName?.formatted()
            freshSignInInfo = SignInInfo(
                displayName: (name?.isEmpty ?? true) ? nil : name,
                email: credential.email
            )
            // If you add a backend later: send credential.identityToken (a JWT)
            // to your server and verify it against Apple's public keys there.
            KeychainHelper.save(credential.user, for: Self.userIDKey)
            errorMessage = nil
            state = .signedIn(userID: credential.user)

        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled { return }
            errorMessage = error.localizedDescription
        }
    }

    /// Hackathon safety net: Sign in with Apple needs a paid developer team
    /// and a signed-in Apple ID. Demo mode keeps the pitch alive if either fails.
    func signInAsDemo() {
        freshSignInInfo = SignInInfo(displayName: "Demo User", email: nil)
        KeychainHelper.save(Self.demoUserID, for: Self.userIDKey)
        state = .signedIn(userID: Self.demoUserID)
    }

    func consumeFreshSignInInfo() -> SignInInfo? {
        defer { freshSignInInfo = nil }
        return freshSignInInfo
    }

    func signOut() {
        KeychainHelper.delete(Self.userIDKey)
        freshSignInInfo = nil
        state = .signedOut
    }
}
