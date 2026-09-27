import Foundation

struct AppConfiguration: Sendable {
    let cognitoDomain: URL
    let clientID: String
    let callbackURL: URL
    let logoutURL: URL
    let backendBaseURL: URL

    static let live: AppConfiguration = {
        guard
            let domain = URL(string: "https://auth.pippipgo.com"),
            let callback = URL(string: "pipgogo://auth/callback"),
            let logout = URL(string: "pipgogo://auth/logout"),
            let backendString = Bundle.main.object(forInfoDictionaryKey: "BackendBaseURL") as? String,
            let backend = URL(string: backendString)
        else { preconditionFailure("The app configuration is invalid.") }
        return AppConfiguration(cognitoDomain: domain, clientID: "5ungc4grbiid7de7rjbh0jn2ff", callbackURL: callback, logoutURL: logout, backendBaseURL: backend)
    }()
}
