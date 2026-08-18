import SwiftUI

struct SignInView: View {
    @Environment(SessionStore.self) private var session

    @State private var email = ""
    @State private var password = ""
    @State private var showsPassword = false

    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    var body: some View {
        ZStack {
            Theme.lavender.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    hero
                    form
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.amber).frame(width: 44, height: 44)
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.navyDark)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("London Hotel Group")
                        .font(Theme.body(13, weight: .heavy))
                        .foregroundStyle(.white)

                    Text("Property Information Hub")
                        .font(Theme.body(10))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()
            }

            Text("One Accurate Record\nfor Every Property")
                .font(Theme.display(29))
                .foregroundStyle(.white)
                .lineSpacing(2)
                .padding(.top, 26)

            Text("We make sure every unit count, lift and staircase is verified by the people on the ground.")
                .font(Theme.body(12))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 8)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.heroGradient)
        .clipShape(
            UnevenRoundedRectangle(bottomLeadingRadius: 36, bottomTrailingRadius: 36, style: .continuous)
        )
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Form

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sign in")
                .font(Theme.display(19))
                .foregroundStyle(Theme.ink)

            VStack(alignment: .leading, spacing: 6) {
                Text("Work email")
                    .font(Theme.body(12, weight: .bold))
                    .foregroundStyle(Theme.navy)

                TextField("name@londonhotelgroup.co.uk", text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                    .fieldChrome()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Password")
                    .font(Theme.body(12, weight: .bold))
                    .foregroundStyle(Theme.navy)

                HStack {
                    Group {
                        if showsPassword {
                            TextField("", text: $password)
                        } else {
                            SecureField("", text: $password)
                        }
                    }
                    .textContentType(.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit(submit)

                    Button {
                        showsPassword.toggle()
                    } label: {
                        Image(systemName: showsPassword ? "eye.slash" : "eye")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showsPassword ? "Hide password" : "Show password")
                }
                .fieldChrome()
            }

            if let error = session.signInError {
                Label {
                    Text(error).font(Theme.body(12, weight: .semibold))
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .foregroundStyle(Theme.red)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.red.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .transition(.opacity)
            }

            HubButton(
                title: session.isSigningIn ? "Signing in…" : "Sign in",
                icon: "arrow.right",
                style: .amber,
                isLoading: session.isSigningIn,
                isDisabled: !canSubmit,
                action: submit
            )
            .frame(maxWidth: .infinity)

            if !APIConfiguration.isProduction, !APIConfiguration.environmentLabel.isEmpty {
                // Tells a tester which server a build points at, so a confusing
                // "my change isn't here" is a five-second check.
                Label(
                    "Connected to \(APIConfiguration.environmentLabel) · \(APIConfiguration.baseURL.host() ?? "")",
                    systemImage: "antenna.radiowaves.left.and.right"
                )
                .font(Theme.body(10, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .padding(.top, 2)
            }

            Text("Access is managed by your corporate administrator. Contact them if you cannot sign in.")
                .font(Theme.body(11))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
        .padding(24)
        .background(Color.white, in: RoundedRectangle(cornerRadius: Theme.heroRadius, style: .continuous))
        .shadow(color: Theme.navy.opacity(0.1), radius: 20, y: 8)
        .padding(20)
        .animation(.easeOut(duration: 0.2), value: session.signInError)
    }

    private func submit() {
        guard canSubmit else { return }

        focusedField = nil

        Task { await session.signIn(email: email, password: password) }
    }
}
