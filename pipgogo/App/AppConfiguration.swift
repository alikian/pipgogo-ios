import Foundation

enum AppEnvironment: String, Sendable {
    case local, dev, prod

    var keychainService: String {
        // Preserve the installed local app's session; hosted builds get separate token stores.
        let original = "com.pipgogo.ios.authentication"
        return self == .local ? original : "\(original).\(rawValue)"
    }
}

enum AppConfigurationError: Error, Equatable {
    case invalidValue(String)
}

struct AppConfiguration: Sendable {
    let cognitoDomain: URL
    let clientID: String
    let callbackURL: URL
    let logoutURL: URL
    let backendBaseURL: URL
    var environment: AppEnvironment = .local

    static let live: AppConfiguration = {
        do { return try from(info: Bundle.main.infoDictionary ?? [:]) }
        catch { preconditionFailure("The app build configuration is invalid: \(error)") }
    }()

    static func from(info: [String: Any]) throws -> AppConfiguration {
        func value(_ key: String) throws -> String {
            guard let value = info[key] as? String, !value.isEmpty, !value.contains("$(") else {
                throw AppConfigurationError.invalidValue(key)
            }
            return value
        }
        guard let environment = AppEnvironment(rawValue: try value("AppEnvironment")) else {
            throw AppConfigurationError.invalidValue("AppEnvironment")
        }
        func baseURL(_ key: String, allowHTTP: Bool = false) throws -> URL {
            guard let url = URL(string: try value(key)), let host = url.host, !host.isEmpty,
                  url.scheme == "https" || (allowHTTP && url.scheme == "http"),
                  url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
                  url.path.isEmpty || url.path == "/" else { throw AppConfigurationError.invalidValue(key) }
            return url
        }
        let backend = try baseURL("BackendBaseURL", allowHTTP: environment == .local)
        let expectedHost: String? = switch environment {
        case .local: nil
        case .dev: "api-dev.pippipgo.com"
        case .prod: "api.pippipgo.com"
        }
        if let expectedHost, backend.host != expectedHost || backend.port != nil {
            throw AppConfigurationError.invalidValue("BackendBaseURL")
        }
        let domain = try baseURL("CognitoDomain")
        let clientID = try value("CognitoClientID")
        let expectedAuth = environment == .prod ? "auth.pippipgo.com" : "auth-dev.pippipgo.com"
        guard domain.host == expectedAuth, domain.port == nil else {
            throw AppConfigurationError.invalidValue("CognitoDomain")
        }
        if environment == .prod, clientID == "5ungc4grbiid7de7rjbh0jn2ff" {
            throw AppConfigurationError.invalidValue("CognitoClientID")
        }
        return AppConfiguration(
            cognitoDomain: domain,
            clientID: clientID,
            callbackURL: URL(string: "pipgogo://auth/callback")!,
            logoutURL: URL(string: "pipgogo://auth/logout")!,
            backendBaseURL: backend,
            environment: environment
        )
    }
}
