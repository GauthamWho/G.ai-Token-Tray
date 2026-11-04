// G.AI TokenTray by GauthamWho. Copyright © 2026 GauthamWho. All rights reserved. See LICENSE.
import SwiftUI

@main
struct TokenTrayApp: App {
    @StateObject private var store = Store()

    init() { PanelSnapshot.runIfRequested() }

    var body: some Scene {
        MenuBarExtra {
            PanelView().environmentObject(store)
        } label: {
            Image(nsImage: store.trayIcon)
        }
        .menuBarExtraStyle(.window)
    }
}
