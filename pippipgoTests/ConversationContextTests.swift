import CoreLocation
import Foundation
import Testing
@testable import pippipgo

struct ConversationContextTests {
    @Test func preciseLocationAccuracyAndStaleFix() {
        let now = Date()
        let fix = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), altitude: 0, horizontalAccuracy: 8, verticalAccuracy: -1, timestamp: now)
        let context = ConversationContext.snapshot(location: fix, now: now, timezone: TimeZone(identifier: "America/Los_Angeles")!)
        #expect(context.location?.latitude == 37.7749)
        #expect(context.location?.longitude == -122.4194)
        #expect(context.location?.horizontal_accuracy_meters == 8)
        #expect(context.timezone == "America/Los_Angeles")
        #expect(ConversationContext.snapshot(location: fix, now: now.addingTimeInterval(61)).location == nil)
        #expect(ConversationContext.snapshot(now: now).location == nil)
    }

    @Test func reducedAccuracyIsReportedHonestlyAndInvalidFixIsOmitted() throws {
        let now = Date()
        let coarse = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), altitude: 0, horizontalAccuracy: 5000, verticalAccuracy: -1, timestamp: now)
        let context = ConversationContext.snapshot(location: coarse, now: now)
        #expect(context.location?.horizontal_accuracy_meters == 5000)
        let encoded = try JSONEncoder().encode(context)
        let decoded = try JSONDecoder().decode(ConversationContext.self, from: encoded)
        #expect(decoded.location?.latitude == 37.7749)
        #expect(decoded.location?.horizontal_accuracy_meters == 5000)
        let invalid = CLLocation(coordinate: coarse.coordinate, altitude: 0, horizontalAccuracy: -1, verticalAccuracy: -1, timestamp: now)
        #expect(ConversationContext.snapshot(location: invalid, now: now).location == nil)
    }

    @MainActor @Test func accountResetDiscardsInFlightContext() async {
        var continuation: CheckedContinuation<ConversationContext, Never>?
        let store = TravelChatStore(client: APIClient(baseURL: URL(string: "https://example.invalid")!), authentication: ContextTokens(), captureContext: {
            await withCheckedContinuation { continuation = $0 }
        })
        store.loaded = true; store.composer = "Nearby ideas?"
        let task = Task { await store.send() }
        while continuation == nil { await Task.yield() }
        store.reset()
        continuation?.resume(returning: .snapshot())
        await task.value
        #expect(store.pending == nil)
        #expect(!store.busy && !store.loaded && store.composer.isEmpty)
    }
}

private struct ContextTokens: AccessTokenProviding {
    func validAccessToken(forceRefresh: Bool) async throws -> String { "test" }
}

@MainActor private final class TestLocationManager: CLLocationManager {
    var authorization: CLAuthorizationStatus = .authorizedWhenInUse
    var precision: CLAccuracyAuthorization = .fullAccuracy
    var starts = 0
    var stops = 0
    override var authorizationStatus: CLAuthorizationStatus { authorization }
    override var accuracyAuthorization: CLAccuracyAuthorization { precision }
    override func startUpdatingLocation() { starts += 1 }
    override func stopUpdatingLocation() { stops += 1 }
    override func requestWhenInUseAuthorization() {}
}

@MainActor struct LocationAcquisitionTests {
    private func fix(accuracy: Double = 8, age: TimeInterval = 0) -> CLLocation {
        CLLocation(coordinate: CLLocationCoordinate2D(latitude: 37.7749123, longitude: -122.4194567), altitude: 0, horizontalAccuracy: accuracy, verticalAccuracy: -1, timestamp: Date().addingTimeInterval(-age))
    }

    @Test func staleFixAndTemporaryErrorWaitForFreshPreciseFix() async {
        let manager = TestLocationManager()
        let collector = ConversationLocationCollector(manager: manager)
        let task = Task { await collector.capture() }
        while manager.starts == 0 { await Task.yield() }
        collector.locationManager(manager, didUpdateLocations: [fix(age: 120)])
        collector.locationManager(manager, didFailWithError: CLError(.locationUnknown))
        #expect(manager.stops == 0)
        collector.locationManager(manager, didUpdateLocations: [fix(accuracy: 500)])
        #expect(manager.stops == 0)
        collector.locationManager(manager, didUpdateLocations: [fix()])
        let result = await task.value
        #expect(result?.horizontalAccuracy == 8)
        #expect(collector.status == "available")
        #expect(manager.stops == 1)
        #expect(manager.desiredAccuracy == kCLLocationAccuracyBest)
    }

    @Test func deniedPermissionReportsReasonImmediately() async {
        let manager = TestLocationManager(); manager.authorization = .denied
        let collector = ConversationLocationCollector(manager: manager)
        #expect(await collector.capture() == nil)
        #expect(collector.status == "permission_denied")
        #expect(manager.starts == 0)
    }

    @Test func timeoutKeepsBestAvailableAccuracy() async {
        let manager = TestLocationManager()
        let collector = ConversationLocationCollector(manager: manager, captureTimeout: .milliseconds(50))
        let task = Task { await collector.capture() }
        while manager.starts == 0 { await Task.yield() }
        collector.locationManager(manager, didUpdateLocations: [fix(accuracy: 500), fix(accuracy: 70), fix(accuracy: 200)])
        #expect(await task.value?.horizontalAccuracy == 70)
        #expect(collector.status == "available")
    }

    @Test func missingFixReportsTimeoutAndCancellationStopsUpdates() async {
        let manager = TestLocationManager()
        let collector = ConversationLocationCollector(manager: manager, captureTimeout: .milliseconds(10))
        #expect(await collector.capture() == nil)
        #expect(collector.status == "timed_out")
        let another = TestLocationManager()
        let cancelled = ConversationLocationCollector(manager: another)
        let task = Task { await cancelled.capture() }
        while another.starts == 0 { await Task.yield() }
        task.cancel()
        #expect(await task.value == nil)
        #expect(cancelled.status == "cancelled")
        #expect(another.stops == 1)
    }

    @Test func reducedAccuracyAndMissingContextAreNotMisrepresented() async {
        let manager = TestLocationManager(); manager.precision = .reducedAccuracy
        let collector = ConversationLocationCollector(manager: manager)
        let task = Task { await collector.capture() }
        while manager.starts == 0 { await Task.yield() }
        collector.locationManager(manager, didUpdateLocations: [fix(accuracy: 5000)])
        let context = ConversationContext.snapshot(location: await task.value, status: collector.status)
        #expect(context.location_status == "approximate")
        #expect(context.location?.horizontal_accuracy_meters == 5000)
        #expect(!ConversationContext.snapshot().hasFreshLocation())
        #expect(context.hasFreshLocation())
        #expect(!context.hasFreshLocation(now: Date().addingTimeInterval(61)))
    }
}

// Explicitly enabled only for physical-device acceptance; no coordinates are logged.
@MainActor struct PhysicalLocationDiagnostic {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["PIPPIPGO_LOCATION_DIAGNOSTIC"] == "1"))
    func captureFreshLocation() async {
        let context = await ConversationContext.capture()
        print("PIPPIPGO_LOCATION_DIAGNOSTIC status=\(context.location_status) accuracy_m=\(context.location?.horizontal_accuracy_meters.description ?? "unavailable")")
        #expect(context.hasFreshLocation())
        #expect(context.location_status == "available")
    }
}

@MainActor struct NearbyAddressTests {
    private func context(latitude: Double = 37.7749, accuracy: Double = 8) -> ConversationContext {
        .snapshot(location: CLLocation(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: -122.4194), altitude: 0, horizontalAccuracy: accuracy, verticalAccuracy: -1, timestamp: Date()))
    }

    @Test func cachesNearbyAddressAndThrottlesMovementLookups() async {
        var current = context()
        var now = Date()
        var lookups = 0
        let store = CurrentLocationStore(capture: { current }, resolve: { _, _ in lookups += 1; return "Market Street, San Francisco" }, now: { now })
        await store.refresh()
        #expect(store.address == "Market Street, San Francisco")
        await store.refresh()
        #expect(lookups == 1)
        current = context(latitude: 38)
        await store.refresh()
        #expect(store.address == nil) // Do not label a new position with the old address.
        #expect(lookups == 1)
        now = now.addingTimeInterval(61)
        await store.refresh()
        #expect(lookups == 2)
    }

    @Test func coarseFixRequestsAreaAndFailuresNeverExposeCoordinates() async {
        let broad = context(accuracy: 5000)
        var requestedArea = false
        let store = CurrentLocationStore(capture: { broad }, resolve: { _, area in requestedArea = area; return nil })
        await store.refresh()
        #expect(requestedArea)
        #expect(store.address == nil)
        #expect(store.context?.location != nil)
        #expect(!store.isUpdating)
    }

    @Test func accountResetDiscardsLateAddressResponse() async {
        let fix = context()
        var continuation: CheckedContinuation<String?, Never>?
        let store = CurrentLocationStore(capture: { fix }, resolve: { _, _ in await withCheckedContinuation { continuation = $0 } })
        let task = Task { await store.refresh() }
        while continuation == nil { await Task.yield() }
        store.reset()
        continuation?.resume(returning: "Old account address")
        await task.value
        #expect(store.address == nil && store.context == nil && !store.isUpdating)
    }

    @Test func automaticStartIsSingleAndStopsLateCapture() async {
        var captures = 0
        var continuation: CheckedContinuation<ConversationContext, Never>?
        let store = CurrentLocationStore(capture: { captures += 1; return await withCheckedContinuation { continuation = $0 } }, resolve: { _, _ in "Should not appear" })
        store.start(); store.start()
        while continuation == nil { await Task.yield() }
        #expect(captures == 1)
        store.stop()
        continuation?.resume(returning: context())
        await Task.yield()
        #expect(store.context == nil && store.address == nil && !store.isUpdating)
    }
}
