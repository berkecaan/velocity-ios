import SwiftUI
import MapKit
import Charts

struct Dashboard: View {
    @EnvironmentObject var drive: DriveStore
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("mph") private var mph = false
    @AppStorage("limit") private var limit = 90.0
    @AppStorage("awake") private var awake = true
    @AppStorage("theme") private var theme = "mint"
    @State private var hud = false
    @State private var sheet: Panel?
    enum Panel: String, Identifiable { case settings, history, map; var id: String { rawValue } }
    var tint: Color { theme == "amber" ? .orange : theme == "ice" ? .cyan : Color(red: 0.45, green: 1, blue: 0.72) }
    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            ZStack {
                LinearGradient(colors: [Color(red: 0.045, green: 0.09, blue: 0.1), .black], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
                VStack(spacing: landscape ? 8 : 22) {
                    header
                    if landscape {
                        HStack(spacing: 28) {
                            gauge.frame(maxWidth: .infinity)
                            VStack(spacing: 12) { tripStats; graph; tripButton }.frame(width: geo.size.width * 0.34)
                        }
                    } else {
                        Spacer(minLength: 0)
                        gauge
                        tripStats
                        graph.frame(height: 95)
                        tripButton
                        Spacer(minLength: 0)
                    }
                    footer
                }.padding(.horizontal, landscape ? 26 : 22).padding(.vertical, 12)
                    .scaleEffect(x: hud ? -1 : 1, y: 1)
            }
        }
        .tint(tint)
        .onAppear { drive.authorize(); updateAwake() }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: awake) { _, _ in updateAwake() }
        .onChange(of: scenePhase) { _, phase in
            updateAwake()
            if phase == .active { drive.authorize() }
            if phase == .background { drive.finishTrip() }
        }
        .sheet(item: $sheet) { panel in
            switch panel {
            case .settings: SettingsView()
            case .history: HistoryView()
            case .map: RouteView()
            }
        }
    }
    private func updateAwake() { UIApplication.shared.isIdleTimerDisabled = awake && scenePhase == .active }
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("VELOCITY").font(.system(size: 22, weight: .black, design: .rounded)).tracking(5)
                Text("PRECISION DRIVE").font(.system(size: 9, weight: .semibold)).tracking(4).foregroundStyle(.secondary)
            }
            Spacer()
            Label(drive.status, systemImage: drive.speed == nil ? "location.slash" : "location.fill")
                .font(.caption).foregroundStyle(drive.speed == nil ? Color.orange : tint)
            Button { sheet = .settings } label: { Image(systemName: "slider.horizontal.3").padding(12).background(.white.opacity(0.06), in: Circle()) }.accessibilityLabel("Ayarlar")
        }
    }
    private var gauge: some View {
        VStack(spacing: 4) {
            ZStack {
                Dial(progress: min(1, SpeedMath.display(drive.speed ?? 0, mph: mph) / (mph ? 160 : 260)), tint: drive.exceeded ? .red : tint)
                VStack(spacing: 2) {
                    Text(drive.speed.map { String(Int(SpeedMath.display($0, mph: mph).rounded())) } ?? "—")
                        .font(.system(size: 104, weight: .heavy, design: .rounded)).monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(drive.exceeded ? Color.red : .white)
                        .minimumScaleFactor(0.5).lineLimit(1)
                        .shadow(color: tint.opacity(0.18), radius: 22)
                    Text(mph ? "MPH" : "KM / H").font(.system(size: 13, weight: .bold)).tracking(5).foregroundStyle(tint)
                    Text(drive.speed == nil ? "SİNYAL BEKLENİYOR" : drive.exceeded ? "HIZ SINIRI AŞILDI" : "CANLI GPS HIZI")
                        .font(.system(size: 9, weight: .bold)).tracking(2).foregroundStyle(drive.exceeded ? Color.red : .secondary).padding(.top, 10)
                }.padding(.horizontal, 46)
            }.aspectRatio(1.55, contentMode: .fit)
            HStack(spacing: 24) {
                Label("\(Int(limit)) \(mph ? "mph" : "km/h")", systemImage: "exclamationmark.circle")
                Label(drive.accuracy.map { "±\(Int($0)) m" } ?? "—", systemImage: "scope")
                Label(drive.heading.map { "\(Int($0))°" } ?? "—", systemImage: "location.north")
            }.font(.caption).foregroundStyle(.secondary)
        }.accessibilityElement(children: .combine)
    }
    private var tripStats: some View {
        HStack(spacing: 10) {
            metric("MESAFE", String(format: "%.1f", (drive.activeTrip?.distance ?? 0) / (mph ? 1609.344 : 1000)), mph ? "mi" : "km")
            metric("ORTALAMA", String(Int(SpeedMath.display(drive.activeTrip?.average ?? 0, mph: mph))), mph ? "mph" : "km/h")
            metric("MAKSİMUM", String(Int(SpeedMath.display(drive.activeTrip?.topSpeed ?? 0, mph: mph))), mph ? "mph" : "km/h")
        }
    }
    private func metric(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(.system(size: 8, weight: .bold)).tracking(1.3).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.system(size: 25, weight: .bold, design: .rounded)).monospacedDigit().minimumScaleFactor(0.5)
                Text(unit).font(.system(size: 9)).foregroundStyle(tint)
            }.lineLimit(1)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.06)))
    }
    private var graph: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("SON 90 ÖLÇÜM").font(.system(size: 8, weight: .bold)).tracking(2)
                Spacer()
                if let trip = drive.activeTrip { Text(duration(trip.duration)).font(.caption.monospacedDigit()).foregroundStyle(tint) }
            }.foregroundStyle(.secondary)
            Chart(drive.samples) { point in
                AreaMark(x: .value("Zaman", point.date), y: .value("Hız", SpeedMath.display(point.speed, mph: mph)))
                    .foregroundStyle(LinearGradient(colors: [tint.opacity(0.25), tint.opacity(0)], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Zaman", point.date), y: .value("Hız", SpeedMath.display(point.speed, mph: mph))).foregroundStyle(tint).lineStyle(StrokeStyle(lineWidth: 2))
            }.chartXAxis(.hidden).chartYAxis(.hidden).chartYScale(domain: 0...max(30, SpeedMath.display(drive.samples.map(\.speed).max() ?? 0, mph: mph) * 1.2))
                .frame(minHeight: 35, maxHeight: 68)
        }.padding(12).background(.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 14))
    }
    private var tripButton: some View {
        Button {
            if drive.activeTrip == nil { drive.startTrip() } else { drive.finishTrip() }
        } label: {
            Label(drive.activeTrip == nil ? "SÜRÜŞÜ BAŞLAT" : "SÜRÜŞÜ KAYDET", systemImage: drive.activeTrip == nil ? "play.fill" : "stop.fill")
                .font(.system(size: 13, weight: .bold)).tracking(1.5).frame(maxWidth: .infinity).padding(16)
                .foregroundStyle(.black).background(tint, in: RoundedRectangle(cornerRadius: 18))
        }.disabled(drive.speed == nil && drive.activeTrip == nil)
    }
    private var footer: some View {
        HStack {
            Button { hud.toggle() } label: { Label("HUD", systemImage: "rectangle.on.rectangle") }.foregroundStyle(hud ? tint : .secondary)
            Spacer()
            Button { sheet = .map } label: { Label("Harita", systemImage: "map") }
            Spacer()
            Button { sheet = .history } label: { Label("Geçmiş", systemImage: "clock.arrow.circlepath") }
        }.font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary).padding(.top, 4)
    }
}
struct Dial: View {
    let progress: Double
    let tint: Color
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height * 0.73)
            let radius = min(size.width * 0.44, size.height * 0.66)
            for index in 0...52 {
                let angle = Double(150 + index * 5) * .pi / 180
                let major = index % 4 == 0
                let inner = radius - (major ? 17.0 : 8.0)
                var line = Path()
                line.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
                line.addLine(to: CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius))
                context.stroke(line, with: .color(Double(index) / 52 <= progress ? tint : .white.opacity(major ? 0.25 : 0.09)), style: StrokeStyle(lineWidth: major ? 3 : 1.5, lineCap: .round))
            }
        }.accessibilityHidden(true)
    }
}
func duration(_ seconds: Double) -> String {
    let value = Int(max(0, seconds))
    return String(format: "%02d:%02d:%02d", value / 3600, value / 60 % 60, value % 60)
}
