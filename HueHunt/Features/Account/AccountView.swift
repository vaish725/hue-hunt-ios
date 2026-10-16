import SwiftUI

// Email sign-in (a code sent to your inbox) plus the one-time username claim that follows the
// first sign-in (PRD F1 AC3-4, using email OTP in place of Sign in with Apple for now). Reached
// from the Profile tab's Account section, both before and after sign-in.
struct AccountView: View {
  @Environment(AuthService.self) private var authService

  @State private var email = ""
  @State private var code = ""
  @State private var username = ""
  @State private var stage: Stage = .emailEntry
  @State private var errorMessage: String?
  @State private var isWorking = false
  @State private var usernameAvailability: UsernameAvailability = .unknown
  @State private var usernameCheckTask: Task<Void, Never>?

  private enum Stage {
    case emailEntry
    case codeEntry
  }

  private enum UsernameAvailability: Equatable {
    case unknown, checking, available, taken, invalid
  }

  var body: some View {
    Form {
      if authService.needsUsername {
        usernameSection
      } else {
        switch stage {
        case .emailEntry: emailSection
        case .codeEntry: codeSection
        }
      }

      if let errorMessage {
        Section {
          Text(errorMessage).foregroundStyle(.red)
        }
      }
    }
    .navigationTitle("Sign In")
    .disabled(isWorking)
  }

  private var emailSection: some View {
    Section {
      TextField("Email", text: $email)
        .textContentType(.emailAddress)
        .keyboardType(.emailAddress)
        .textInputAutocapitalization(.never)
      Button("Send Code") {
        Task { await sendCode() }
      }
      .disabled(email.isEmpty)
    } footer: {
      Text("We'll email you a 6-digit code. No password needed.")
    }
  }

  private var codeSection: some View {
    Section {
      Text("Enter the code sent to \(email)")
      TextField("Code", text: $code)
        .keyboardType(.numberPad)
      Button("Verify") {
        Task { await verifyCode() }
      }
      .disabled(code.isEmpty)
      Button("Use a Different Email") {
        stage = .emailEntry
        code = ""
      }
    }
  }

  private var usernameSection: some View {
    Section {
      TextField("Username", text: $username)
        .textInputAutocapitalization(.never)
        .onChange(of: username) { _, newValue in
          checkUsername(newValue)
        }
      usernameStatusView
      Button("Claim Username") {
        Task { await claimUsername() }
      }
      .disabled(usernameAvailability != .available)
    } footer: {
      Text("3-20 lowercase letters, numbers, or underscores. Friends find you by this.")
    }
  }

  @ViewBuilder
  private var usernameStatusView: some View {
    switch usernameAvailability {
    case .unknown, .invalid:
      EmptyView()
    case .checking:
      Text("Checking...").foregroundStyle(.secondary)
    case .available:
      Label("Available", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
    case .taken:
      Label("Already taken", systemImage: "xmark.circle.fill").foregroundStyle(.red)
    }
  }

  private func sendCode() async {
    isWorking = true
    defer { isWorking = false }
    do {
      try await authService.sendSignInCode(to: email)
      stage = .codeEntry
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func verifyCode() async {
    isWorking = true
    defer { isWorking = false }
    do {
      try await authService.verifySignInCode(email: email, code: code)
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func checkUsername(_ candidate: String) {
    usernameCheckTask?.cancel()
    guard isValidUsernameFormat(candidate) else {
      usernameAvailability = candidate.isEmpty ? .unknown : .invalid
      return
    }
    usernameAvailability = .checking
    usernameCheckTask = Task {
      try? await Task.sleep(for: .milliseconds(400))
      guard !Task.isCancelled else { return }
      do {
        let isAvailable = try await authService.isUsernameAvailable(candidate)
        guard !Task.isCancelled else { return }
        usernameAvailability = isAvailable ? .available : .taken
      } catch {
        usernameAvailability = .unknown
      }
    }
  }

  private func isValidUsernameFormat(_ candidate: String) -> Bool {
    candidate.range(of: "^[a-z0-9_]{3,20}$", options: .regularExpression) != nil
  }

  private func claimUsername() async {
    isWorking = true
    defer { isWorking = false }
    do {
      try await authService.claimUsername(username)
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

#Preview {
  NavigationStack {
    AccountView()
  }
  .environment(AuthService(client: .live))
}
