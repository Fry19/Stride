import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if model.state.hasOnboarded {
                TabView {
                    TodayView()
                        .tabItem { Label("Today", systemImage: "figure.walk") }
                    JourneyView()
                        .tabItem { Label("Journey", systemImage: "map") }
                    PassportView()
                        .tabItem { Label("Passport", systemImage: "seal") }
                    RewardsView()
                        .tabItem { Label("Rewards", systemImage: "gift") }
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
