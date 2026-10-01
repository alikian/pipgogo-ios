import CoreLocation
import Foundation
import MapKit
import Observation

@MainActor enum NearbyAddressResolver {
    static func resolve(_ location: CLLocation, approximate: Bool) async throws -> String? {
        if #available(iOS 26.0, *) {
            guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
            let timeout = Task { try? await Task.sleep(for: .seconds(10)); if !Task.isCancelled { request.cancel() } }
            defer { timeout.cancel() }
            return try await withTaskCancellationHandler {
                let item = try await request.mapItems.first
                if approximate { return item?.addressRepresentations?.cityWithContext ?? item?.addressRepresentations?.regionName }
                return item?.addressRepresentations?.fullAddress(includingRegion: false, singleLine: true) ?? item?.address?.shortAddress
            } onCancel: { Task { @MainActor in request.cancel() } }
        } else {
            let geocoder = CLGeocoder()
            let timeout = Task { try? await Task.sleep(for: .seconds(10)); if !Task.isCancelled { geocoder.cancelGeocode() } }
            defer { timeout.cancel() }
            return try await withTaskCancellationHandler {
                guard let place = try await geocoder.reverseGeocodeLocation(location).first else { return nil }
                let street = [place.subThoroughfare, place.thoroughfare].compactMap { $0 }.joined(separator: " ")
                let parts = approximate ? [place.locality, place.administrativeArea, place.country] : [street.isEmpty ? nil : street, place.subLocality, place.locality, place.administrativeArea]
                var unique: [String] = []
                for part in parts.compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) }) where !part.isEmpty && !unique.contains(part) { unique.append(part) }
                return unique.isEmpty ? nil : unique.joined(separator: ", ")
            } onCancel: { Task { @MainActor in geocoder.cancelGeocode() } }
        }
    }
}

/// Foreground display state is separate from immutable chat retries and voice-session context.
@MainActor @Observable final class CurrentLocationStore {
    private(set) var context: ConversationContext?
    private(set) var address: String?
    private(set) var isUpdating = false
    private var generation = UUID()
    private var worker: Task<Void, Never>?
    private let capture: @MainActor () async -> ConversationContext
    private let resolve: @MainActor (CLLocation, Bool) async throws -> String?
    private let now: () -> Date
    private var lastLookup: Date?
    private var cached: (location: CLLocation, approximate: Bool, address: String, date: Date)?

    init(capture: @escaping @MainActor () async -> ConversationContext = { await ConversationContext.capture() },
         resolve: @escaping @MainActor (CLLocation, Bool) async throws -> String? = { try await NearbyAddressResolver.resolve($0, approximate: $1) },
         now: @escaping () -> Date = Date.init) {
        self.capture = capture; self.resolve = resolve; self.now = now
    }

    func start() {
        guard worker == nil else { return }
        worker = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
            }
        }
    }

    func stop() {
        worker?.cancel(); worker = nil
        generation = UUID(); isUpdating = false
    }

    func reset() {
        stop(); context = nil; address = nil; cached = nil; lastLookup = nil
    }

    func refresh() async {
        guard !isUpdating else { return }
        let ticket = generation
        isUpdating = true
        defer { if ticket == generation { isUpdating = false } }
        let captured = await capture()
        guard ticket == generation, !Task.isCancelled else { return }
        context = captured
        guard let fix = captured.location else { address = nil; return }
        let location = CLLocation(latitude: fix.latitude, longitude: fix.longitude)
        let approximate = captured.location_status == "approximate" || fix.horizontal_accuracy_meters > 100
        let date = now()
        if let cached, cached.approximate == approximate, date.timeIntervalSince(cached.date) < 300,
           location.distance(from: cached.location) < 50 {
            address = cached.address
            return
        }
        address = nil
        // Respect geocoding rate limits even across foreground/background transitions.
        if let lastLookup, date.timeIntervalSince(lastLookup) < 60 { return }
        lastLookup = date
        do {
            let result = try await resolve(location, approximate)?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard ticket == generation, !Task.isCancelled else { return }
            guard let result, !result.isEmpty else { return }
            address = result
            cached = (location, approximate, result, date)
        } catch { /* The view explicitly reports address lookup unavailability. */ }
    }
}
