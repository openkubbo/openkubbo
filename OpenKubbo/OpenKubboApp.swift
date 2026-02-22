//
//  OpenKubboApp.swift
//  OpenKubbo
//
//  Created by Tarik Villalobos on 2/21/26.
//

import SwiftUI
import AppKit

@main
struct OpenKubboApp: App {
    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 12) {
                ContentView()

                Divider()

                Button("Quit OpenKubbo") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(12)
            .frame(width: 220)
        } label: {
            Image("OpenKubbo")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .accessibilityLabel("OpenKubbo")
        }
        .menuBarExtraStyle(.window)
    }
}
