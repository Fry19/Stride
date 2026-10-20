import SwiftUI

enum AppTab: String {
    case today, journey, passport, rewards
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = ScreenshotMode.initialTab

    var body: some View {
        Group {
            if model.state.hasOnboarded {
                TabView(selection: $tab) {
                    TodayView()
                        .tabItem { Label("Today", systemImage: "figure.walk") }
                        .tag(AppTab.today)
                    JourneyView()
                        .tabItem { Label("Journey", systemImage: "map") }
                        .tag(AppTab.journey)
                    PassportView()
                        .tabItem { Label("Passport", systemImage: "seal") }
                        .tag(AppTab.passport)
                    RewardsView()
                        .tabItem { Label("Rewards", systemImage: "gift") }
                        .tag(AppTab.rewards)
                }
            } else {
                OnboardingView()
            }
        }
        .tint(Color.blaze)
        .sheet(isPresented: showingCelebration) {
            CelebrationView(unlocks: model.celebration) {
                model.finishCelebration()
            }
        }
        .task {
            await model.refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await model.refresh() }
            case .background:
                model.stopLiveUpdates()
                model.save()
            default:
                break
            }
        }
    }

    private var showingCelebration: Binding<Bool> {
        Binding(
            get: { !model.celebration.isEmpty },
            set: { isShowing in
                if !isShowing { model.finishCelebration() }
            })
    }
}
