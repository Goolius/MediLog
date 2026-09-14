//
//  ContentView.swift
//  MediLog
//
//  Created by My Mac on 13/09/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MediLogViewModel()

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView(viewModel: viewModel)
            }
            .tabItem {
                Label("Today", systemImage: "calendar")
            }

            NavigationStack {
                AddMedicationView(viewModel: viewModel)
            }
            .tabItem {
                Label("Add", systemImage: "plus.circle")
            }

            NavigationStack {
                HistoryView(viewModel: viewModel)
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
        }
        .alert(item: $viewModel.patientMessage) { patientMessage in
            Alert(
                title: Text(patientMessage.title),
                message: Text(patientMessage.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

#Preview {
    ContentView()
}
