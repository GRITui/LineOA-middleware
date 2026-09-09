import SwiftUI

@main
struct AdminMacOSApp: App {
    var body: some Scene {
        WindowGroup("LineOA Admin") {
            SessionListView()
                .frame(minWidth: 720, minHeight: 480)
        }
    }
}
