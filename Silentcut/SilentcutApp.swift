//
//  SilentcutApp.swift
//  Silentcut
//
//  Created by Sarvpriya Adarsh on 06/06/26.
//

import SwiftUI

@main
struct SilentcutApp: App {
    var body: some Scene {
        Window("Silentcut", id: "main") {
            MainView()
                .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}
