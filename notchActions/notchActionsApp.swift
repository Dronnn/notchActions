//
//  NotchActionsApp.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import SwiftUI

@main
struct NotchActionsApp: App {
    @NSApplicationDelegateAdaptor(AppController.self) private var appController

    var body: some Scene {
        // no visible window: notchActions is a menu-bar utility driven by AppController
        Settings { EmptyView() }
    }
}
