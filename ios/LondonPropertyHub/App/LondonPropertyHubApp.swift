import SwiftUI

@main
struct LondonPropertyHubApp: App {

    @State private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .tint(Theme.navy)
                // The design is a single deliberate light palette; forcing it
                // keeps the navy-on-lavender contrast the brand depends on.
                .preferredColorScheme(.light)
        }
    }
}

struct RootView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        Group {
            switch session.state {
            case .launching:
                LaunchView()

            case .signedOut:
                SignInView()
                    .transition(.opacity)

            case .signedIn:
                MainShell()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: session.state)
        .task {
            await session.restore()
        }
    }
}

/// Shown for the moment it takes to check for a stored token.
struct LaunchView: View {
    var body: some View {
        ZStack {
            Theme.heroGradient.ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle().fill(Theme.amber).frame(width: 62, height: 62)
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(Theme.navyDark)
                }

                Text("London Hotel Group")
                    .font(Theme.display(20))
                    .foregroundStyle(.white)

                ProgressView()
                    .tint(.white)
                    .padding(.top, 4)
            }
        }
    }
}
