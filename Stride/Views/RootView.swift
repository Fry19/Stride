import SwiftUI

enum AppTab: String {
    case today, journey, level, trophies
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = ScreenshotMode.initialTab

    var body: some View {
        Group {
            if model.state.hasOnboarded {
                TabView(selection: $tab) {
                    TodayView { tab = .level }
                        .tabItem { Label("Today", systemImage: "figure.walk") }
                        .tag(AppTab.today)
                    JourneyView()
                        .tabItem { Label("Journey", systemImage: "map.fill") }
                        .tag(AppTab.journey)
                    LevelView()
                        .tabItem { Label("Level", systemImage: "rosette") }
                        .tag(AppTab.level)
                    TrophiesView()
                        .tabItem { Label("Trophies", systemImage: "trophy.fill") }
                        .tag(AppTab.trophies)
                }
                .toolbarBackground(Theme.background.opacity(0.92), for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
            } else {
                OnboardingView()
            }
        }
        .tint(Theme.ember)
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: showingCelebration) {
            CelebrationView(unlocks: model.celebration, level: model.summary.level) {
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
                // A walk keeps counting with the phone locked.
                if !model.walk.isActive {
                    model.stopLiveUpdates()
                }
                model.save()
                BackgroundRefresh.schedule()
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
