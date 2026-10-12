import Foundation
import CoreLocation
import UIKit
import Combine
import SwiftUI

struct TrackPoint: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let latitude: Double
    let longitude: Double
    let speed: Double
}
struct Trip: Codable, Identifiable {
    var id = UUID()
    let started: Date
    var ended: Date?
    var distance: Double = 0
    var topSpeed: Double = 0
    var movingTime: Double = 0
    var points: [TrackPoint] = []
    var duration: Double { max(0, (ended ?? Date()).timeIntervalSince(started)) }
    var average: Double { movingTime > 0 ? distance / movingTime : 0 }
}
enum SpeedMath {
    static func display(_ metersPerSecond: Double, mph: Bool) -> Double {
        max(0, metersPerSecond) * (mph ? 2.2369362921 : 3.6)
    }
    static func valid(speed: Double, accuracy: Double, speedAccuracy: Double, age: Double) -> Bool {
        speed.isFinite && speed >= 0 && speed <= 120 && accuracy >= 0 && accuracy <= 50 && speedAccuracy >= 0 && speedAccuracy <= 8 && age >= -2 && age < 5
    }
    static func distanceAllowed(distance: Double, interval: Double, speed: Double) -> Bool {
        interval > 0 && interval <= 5 && distance >= 0 && distance <= max(15, speed * interval * 1.8)
    }
}
@MainActor
final class DriveStore: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var speed: Double? = nil
    @Published var accuracy: Double? = nil
    @Published var altitude: Double? = nil
    @Published var heading: Double? = nil
    @Published var status = "GPS bekleniyor"
    @Published var denied = false
    @Published var activeTrip: Trip?
    @Published var trips: [Trip] = []
    @Published var samples: [TrackPoint] = []
    @Published var location: CLLocation?
    @Published var error: String?
    @Published var exceeded = false
    var mph: Bool { UserDefaults.standard.bool(forKey: "mph") }
    var limit: Double { let v = UserDefaults.standard.double(forKey: "limit"); return v > 0 ? v : 90 }
    private let manager = CLLocationManager()
    private var previous: CLLocation?
    private var lastFix: Date?
    private var lastAlert = Date.distantPast
    private var timer: AnyCancellable?
    private var notifications: [NSObjectProtocol] = []
    private let file = URL.documentsDirectory.appendingPathComponent("trips.json")
    override init() {
        super.init()
        if let data = try? Data(contentsOf: file) {
            do { trips = try JSONDecoder().decode([Trip].self, from: data) }
            catch { self.error = "Yolculuk geçmişi okunamadı. Mevcut dosya korunuyor." }
        }
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .automotiveNavigation
        manager.pausesLocationUpdatesAutomatically = false
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self else { return }
            if self.lastFix == nil || Date().timeIntervalSince(self.lastFix!) > 5 {
                self.invalidate("GPS sinyali bekleniyor")
            }
            if self.activeTrip != nil { self.objectWillChange.send() }
        }
        notifications.append(NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.finishTrip(); self.manager.stopUpdatingLocation(); self.invalidate("Sürüş duraklatıldı")
            }
        })
        notifications.append(NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.authorize() }
        })
    }
    func authorize() {
        guard CLLocationManager.locationServicesEnabled() else { denied = true; status = "Konum servisleri kapalı"; return }
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            denied = false; manager.startUpdatingLocation()
        case .denied, .restricted: denied = true; invalidate("Konum izni gerekli")
        @unknown default: invalidate("Konum kullanılamıyor")
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { authorize() }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        invalidate("GPS kullanılamıyor")
    }
    private func invalidate(_ message: String) {
        speed = nil; accuracy = nil; altitude = nil; heading = nil; location = nil
        previous = nil; exceeded = false; status = denied ? "Konum izni gerekli" : message
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for fix in locations.sorted(by: { $0.timestamp < $1.timestamp }) {
            let age = Date().timeIntervalSince(fix.timestamp)
            guard lastFix == nil || fix.timestamp > lastFix! else { continue }
            guard SpeedMath.valid(speed: fix.speed, accuracy: fix.horizontalAccuracy, speedAccuracy: fix.speedAccuracy, age: age) else {
                invalidate("GPS doğruluğu düşük"); continue
            }
            let value = fix.speed < 0.7 ? 0 : fix.speed
            speed = value; accuracy = fix.horizontalAccuracy; altitude = fix.verticalAccuracy >= 0 ? fix.altitude : nil
            heading = fix.course >= 0 && value > 1 ? fix.course : nil
            location = fix; status = fix.horizontalAccuracy <= 15 ? "GPS güçlü" : "GPS orta"
            lastFix = fix.timestamp
            let point = TrackPoint(date: fix.timestamp, latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude, speed: value)
            samples.append(point); if samples.count > 90 { samples.removeFirst(samples.count - 90) }
            if var trip = activeTrip {
                trip.topSpeed = max(trip.topSpeed, value)
                if let old = previous {
                    let interval = fix.timestamp.timeIntervalSince(old.timestamp)
                    let distance = fix.distance(from: old)
                    if SpeedMath.distanceAllowed(distance: distance, interval: interval, speed: max(value, old.speed)), value > 0 {
                        trip.distance += distance; trip.movingTime += interval
                    }
                }
                // Bound route memory; keep about one point every 5 seconds (max 20,000).
                if trip.points.last.map({ fix.timestamp.timeIntervalSince($0.date) >= 5 }) ?? true {
                    if trip.points.count < 20_000 { trip.points.append(point) }
                }
                activeTrip = trip
            }
            previous = fix
            exceeded = SpeedMath.display(value, mph: mph) > limit
            if exceeded && UserDefaults.standard.object(forKey: "alerts") as? Bool != false && Date().timeIntervalSince(lastAlert) > 15 {
                UINotificationFeedbackGenerator().notificationOccurred(.warning); lastAlert = Date()
            }
        }
    }
    func startTrip() { previous = nil; activeTrip = Trip(started: Date()); error = nil }
    func finishTrip() {
        guard var trip = activeTrip else { return }
        trip.ended = Date(); trips.insert(trip, at: 0); activeTrip = nil; previous = nil
        persist()
    }
    func deleteTrips(at offsets: IndexSet) { trips.remove(atOffsets: offsets); persist() }
    private func persist() {
        do { try JSONEncoder().encode(trips).write(to: file, options: .atomic) }
        catch { self.error = "Geçmiş kaydedilemedi: \(error.localizedDescription)" }
    }
    func export(_ trip: Trip) -> URL? {
        let formatter = ISO8601DateFormatter()
        let rows = trip.points.map { "\(formatter.string(from: $0.date)),\($0.latitude),\($0.longitude),\(SpeedMath.display($0.speed, mph: false))" }
        let url = URL.temporaryDirectory.appendingPathComponent("Velocity-\(trip.id).csv")
        do { try ("time,latitude,longitude,speed_kmh\n" + rows.joined(separator: "\n")).write(to: url, atomically: true, encoding: .utf8); return url }
        catch { self.error = "Dışa aktarma başarısız"; return nil }
    }
}
