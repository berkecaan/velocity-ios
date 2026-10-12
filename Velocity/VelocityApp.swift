import SwiftUI

@main
struct VelocityApp: App {
    @StateObject private var drive = DriveStore()
    var body: some Scene {
        WindowGroup { Dashboard().environmentObject(drive).preferredColorScheme(.dark) }
    }
}
