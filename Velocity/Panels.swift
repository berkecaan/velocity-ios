import SwiftUI
import MapKit

struct SettingsView: View {
    @EnvironmentObject var drive: DriveStore
    @Environment(\.dismiss) var dismiss
    @AppStorage("mph") var mph = false
    @AppStorage("limit") var limit = 90.0
    @AppStorage("awake") var awake = true
    @AppStorage("alerts") var alerts = true
    @AppStorage("theme") var theme = "mint"
    var body: some View {
        NavigationStack {
            Form {
                Section("Gösterge") {
                    Picker("Renk", selection: $theme) { Text("Neon yeşil").tag("mint"); Text("Buz mavisi").tag("ice"); Text("Amber").tag("amber") }
                    Toggle("Mil / saat (mph)", isOn: $mph)
                        .onChange(of: mph) { old, new in limit = max(10, min(new ? 160 : 260, limit * (new ? 0.621371 : 1.609344))) }
                    Toggle("Ekranı açık tut", isOn: $awake)
                }
                Section("Hız uyarısı") {
                    Stepper("Sınır: \(Int(limit)) \(mph ? "mph" : "km/h")", value: $limit, in: 10...(mph ? 160 : 260), step: 5)
                    Toggle("Titreşimli uyarı", isOn: $alerts)
                    Text("Sınırı siz belirlersiniz; yolun gerçek hız sınırı otomatik olarak tespit edilmez.").font(.caption)
                }
                Section("Konum") {
                    Text(drive.status)
                    Button("iOS konum ayarlarını aç") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                    Text("GPS kapalı alanlarda ve tünellerde kullanılamayabilir. Geçersiz ölçümde hız yerine — gösterilir. Kesin konum izni önerilir.").font(.caption)
                }
                Section("Velocity hakkında") {
                    Text("Sürüşler yalnızca bu cihazda tutulur. Konum hiçbir sunucuya gönderilmez. Harita Apple'ın çevrimiçi harita servisini kullanır.")
                    Text("HUD, ekranı aynalar. Ön cam yansımasının kalitesi camınıza ve ışığa bağlıdır.")
                    Text("Uygulama arka plana geçtiğinde sürüş kaydedilir; arka planda takip yapılmaz.")
                    Text("GPS ölçümü aracın resmi hız göstergesinin yerine geçmez. Ayarları park halindeyken yapın.").font(.caption)
                }
            }.navigationTitle("Ayarlar").toolbar { Button("Bitti") { dismiss() } }
        }
    }
}
struct HistoryView: View {
    @EnvironmentObject var drive: DriveStore
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            List {
                if let error = drive.error { Text(error).foregroundStyle(.orange) }
                if drive.trips.isEmpty { ContentUnavailableView("Henüz sürüş yok", systemImage: "road.lanes", description: Text("Ana ekrandan bir sürüş başlatıp kaydedin.")) }
                ForEach(drive.trips) { trip in
                    NavigationLink { TripDetail(trip: trip) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(trip.started.formatted(date: .abbreviated, time: .shortened)).font(.headline)
                            Text(String(format: "%.1f km · %@ · Maks. %.0f km/h", trip.distance / 1000, duration(trip.duration), trip.topSpeed * 3.6)).font(.subheadline).foregroundStyle(.secondary)
                        }.padding(.vertical, 5)
                    }
                }.onDelete(perform: drive.deleteTrips)
            }.navigationTitle("Sürüş geçmişi").toolbar { Button("Bitti") { dismiss() } }
        }
    }
}
struct TripDetail: View {
    @EnvironmentObject var drive: DriveStore
    let trip: Trip
    @State var csv: URL?
    var body: some View {
        List {
            Section {
                LabeledContent("Mesafe", value: String(format: "%.2f km", trip.distance / 1000))
                LabeledContent("Süre", value: duration(trip.duration))
                LabeledContent("Hareket süresi", value: duration(trip.movingTime))
                LabeledContent("Hareket ortalaması", value: String(format: "%.0f km/h", trip.average * 3.6))
                LabeledContent("Maksimum", value: String(format: "%.0f km/h", trip.topSpeed * 3.6))
            }
            Section("Kaydedilen rota") { TrackMap(points: trip.points).frame(height: 260) }
            Section {
                if let csv { ShareLink("CSV paylaş", item: csv) }
                else { Button("CSV hazırla") { csv = drive.export(trip) } }
                if let error = drive.error { Text(error).foregroundStyle(.orange) }
            }
        }.navigationTitle("Sürüş detayı")
    }
}
struct RouteView: View {
    @EnvironmentObject var drive: DriveStore
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            ZStack {
                Map(initialPosition: .userLocation(fallback: .automatic)) {
                    UserAnnotation()
                    if let points = drive.activeTrip?.points, points.count > 1 {
                        MapPolyline(coordinates: points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }).stroke(.mint, lineWidth: 5)
                    }
                }.mapControls { MapUserLocationButton(); MapCompass(); MapScaleView() }
                if drive.denied { ContentUnavailableView("Konum izni gerekli", systemImage: "location.slash", description: Text("Ayarlar'dan konum izni verin.")) }
            }.navigationTitle("Canlı harita").navigationBarTitleDisplayMode(.inline).toolbar { Button("Bitti") { dismiss() } }
        }
    }
}
struct TrackMap: View {
    let points: [TrackPoint]
    var body: some View {
        if points.isEmpty { ContentUnavailableView("Rota yok", systemImage: "map") }
        else {
            Map {
                MapPolyline(coordinates: points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }).stroke(.mint, lineWidth: 4)
                if let start = points.first { Marker("Başlangıç", coordinate: .init(latitude: start.latitude, longitude: start.longitude)).tint(.green) }
                if let end = points.last { Marker("Bitiş", coordinate: .init(latitude: end.latitude, longitude: end.longitude)).tint(.orange) }
            }
        }
    }
}
