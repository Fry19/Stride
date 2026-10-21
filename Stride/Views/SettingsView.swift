import StrideCore
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var goal = RewardRules.defaultGoal

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $goal, in: 1_000...30_000, step: 500) {
                        HStack {
                            Text("Daily goal")
                            Spacer()
                            Text("\(goal.formatted()) steps")
                                .monospacedDigit()
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                } footer: {
                    Text("A new goal starts today. Past days keep the goal they had.")
                }

                Section {
                    LabeledContent("XP counted since", value: StrideFormat.date(model.state.startDay))
                    if let error = model.healthError {
                        Text("Apple Health couldn't be read: \(error)")
                            .foregroundStyle(Theme.ember)
                    }
                } header: {
                    Text("Step data")
                } footer: {
                    Text("Stride reads steps from Apple Health and counts new ones live from your iPhone's motion sensors while the app is open. Steps typed into Health by hand don't count. If steps aren't showing, open the Health app, tap your profile picture, then Apps → Stride.")
                }

                Section {
                    Toggle("Show sample data", isOn: sampleData)
                        .tint(Theme.ember)
                } footer: {
                    Text("Fills Stride with 60 days of made-up walking so you can look around, for example in the simulator. Your real data comes back when you turn it off.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                goal = model.goal
            }
            .onChange(of: goal) { _, newGoal in
                if newGoal != model.goal {
                    model.setGoal(newGoal)
                }
            }
        }
        .presentationBackground(Theme.background)
    }

    private var sampleData: Binding<Bool> {
        Binding(get: { model.state.useSampleData }, set: { model.setUseSampleData($0) })
    }
}
