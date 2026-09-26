import SwiftUI

@main
struct pipgogoApp: App {
    @State private var authenticationStore = AuthenticationStore()

    var body: some Scene {
        WindowGroup {
            RootView(store: authenticationStore)
                .task { await authenticationStore.restoreSession() }
        }
    }
}
