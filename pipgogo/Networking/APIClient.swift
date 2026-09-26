import Foundation

struct APIClient: Sendable {
    let baseURL: URL
    var urlSession: URLSession = .shared

    func account(accessToken: String) async throws -> AccountRecord {
        var request = URLRequest(url: baseURL.appending(path: "/v1/me"))
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIClientError.invalidResponse }
            if http.statusCode == 401 { throw APIClientError.unauthorized }
            guard (200..<300).contains(http.statusCode) else {
                let message = (try? JSONDecoder().decode(APIErrorEnvelope.self, from: data).error.message) ?? "The server returned HTTP \(http.statusCode)."
                throw APIClientError.server(status: http.statusCode, message: message)
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let value = try container.decode(String.self)
                let formatter = ISO8601DateFormatter()

                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatter.date(from: value) {
                    return date
                }

                formatter.formatOptions = [.withInternetDateTime]
                if let date = formatter.date(from: value) {
                    return date
                }

                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Expected an ISO 8601 date."
                )
            }
            do { return try decoder.decode(AccountRecord.self, from: data) }
            catch { throw APIClientError.decoding }
        } catch let error as APIClientError {
            throw error
        } catch let error as URLError where [.cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet, .timedOut].contains(error.code) {
            throw APIClientError.connection
        } catch {
            throw error
        }
    }
}
