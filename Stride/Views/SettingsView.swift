import StrideCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var goal = RewardRules.defaultGoal
    @State private var exporting = false
    @State private var backupToSave: BackupDocument?
    @State private var importing = false
    @State private var backupToRestore: StrideBackup?
    @State private var backupMessage: String?
    @AppStorage("lastBackup") private var lastBackup: Double = 0
    @AppStorage(WalkPreferences.autoPauseKey) private var autoPause = true
    @AppStorage(WalkPreferences.spokenUpdatesKey) private var spokenUpdates = true
    @AppStorage(WalkPreferences.saveToHealthKey) private var saveToHealth = false
    @AppStorage(Nudge.enabledKey) private var nudgeEnabled = false
    @AppStorage(Nudge.minutesKey) private var nudgeMinutes = 19 * 60 + 30
    @State private var nudgeDenied = false

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
                    Toggle("Steps in Dynamic Island", isOn: liveActivity)
                        .tint(Theme.ember)
                } footer: {
                    Text("Shows today's steps on the Lock Screen and in the Dynamic Island. They update live while Stride is open or you're on a walk, and every so often in the background when iOS allows it. iOS ends it after 8 hours; opening Stride starts it again.")
                }

                Section {
                    Toggle("Evening nudge", isOn: nudge)
                        .tint(Theme.ember)
                    if nudgeEnabled {
                        DatePicker("Time", selection: nudgeTime, displayedComponents: .hourAndMinute)
                    }
                } footer: {
                    Text(nudgeDenied
                         ? "Notifications are off for Stride. Turn them on in Settings → Notifications → Stride." as String
                         : "If you haven't hit your goal by then, Stride tells you how many steps are left and roughly how long a walk that is. Nothing is sent on days you've already made it.")
                }

                Section {
                    Toggle("Auto-pause", isOn: $autoPause)
                        .tint(Theme.ember)
                    Toggle("Spoken updates", isOn: $spokenUpdates)
                        .tint(Theme.ember)
                    Toggle("Save walks to Apple Health", isOn: healthWorkouts)
                        .tint(Theme.ember)
                } header: {
                    Text("Walks")
                } footer: {
                    Text("Auto-pause stops the clock when you stand still and starts it when you set off. Spoken updates call out your time and pace every \(StrideFormat.usesMiles ? "half mile" : "kilometer"), and your goal at halfway and the finish. Walks saved to Apple Health appear as workouts in the Health and Fitness apps, with their route.")
                }

                Section {
                    NavigationLink {
                        StatusView()
                    } label: {
                        HStack {
                            Text("Status")
                            Spacer()
                            if model.healthError != nil {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Theme.ember)
                            }
                        }
                    }
                } header: {
                    Text("Step data")
                } footer: {
                    Text("Stride reads steps from Apple Health and counts new ones live from your iPhone's motion sensors while the app is open. Steps typed into Health by hand don't count. Status shows what Stride can see and how to fix anything missing.")
                }

                Section {
                    Button {
                        backupToSave = BackupDocument(backup: model.makeBackup())
                        exporting = true
                    } label: {
                        Label("Save a backup", systemImage: "square.and.arrow.down")
                    }
                    .fileExporter(isPresented: $exporting, document: backupToSave, contentType: .json,
                                  defaultFilename: BackupDocument.defaultFilename) { result in
                        switch result {
                        case .success:
                            lastBackup = Date().timeIntervalSince1970
                            backupMessage = "Backup saved."
                        case .failure(let error):
                            backupMessage = "Couldn't save the backup: \(error.localizedDescription)"
                        }
                    }
                    Button {
                        importing = true
                    } label: {
                        Label("Restore from a backup", systemImage: "clock.arrow.circlepath")
                    }
                    .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                        do {
                            backupToRestore = try BackupDocument.read(from: result.get())
                        } catch {
                            backupMessage = "That file isn't a Stride backup."
                        }
                    }
                } header: {
                    Text("Backup")
                } footer: {
                    Text(backupFooter)
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
            .confirmationDialog("Restore this backup?", isPresented: restoring, titleVisibility: .visible,
                                presenting: backupToRestore) { backup in
                Button("Replace everything", role: .destructive) {
                    model.restore(backup)
                    backupMessage = "Restored. Welcome back to level \(model.summary.level.level)."
                }
            } message: { backup in
                Text("Saved \(backup.exportedAt.formatted(date: .abbreviated, time: .shortened)), with \(backup.state.activity.count) days of steps, \(backup.walks.count) walks and \(backup.state.journeys.count) journeys. It replaces what's on this iPhone now.")
            }
            .alert(backupMessage ?? "", isPresented: showingMessage) {
                Button("OK") {}
            }
            .onChange(of: goal) { _, newGoal in
                if newGoal != model.goal {
                    model.setGoal(newGoal)
                }
            }
        }
        .presentationBackground(Theme.background)
    }

    private var backupFooter: String {
        let saved = lastBackup > 0
            ? "Last saved \(Date(timeIntervalSince1970: lastBackup).formatted(date: .abbreviated, time: .omitted)). "
            : ""
        return saved + "Saves your XP, journeys, quests and walks to a file, for example in iCloud Drive. Deleting Stride deletes them, so save one before reinstalling."
    }

    private var nudge: Binding<Bool> {
        Binding(get: { nudgeEnabled }, set: { on in
            nudgeEnabled = on
            Task {
                let enabled = await model.setNudgeEnabled(on)
                nudgeDenied = on && !enabled
            }
        })
    }

    /// The nudge time as a date today, for the picker.
    private var nudgeTime: Binding<Date> {
        Binding(
            get: { Calendar.current.startOfDay(for: Date()).addingTimeInterval(Double(nudgeMinutes) * 60) },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                nudgeMinutes = (parts.hour ?? 19) * 60 + (parts.minute ?? 30)
                model.updateNudge()
            })
    }

    private var healthWorkouts: Binding<Bool> {
        Binding(get: { saveToHealth }, set: { on in
            saveToHealth = on
            Task { await model.setSavesWalksToHealth(on) }
        })
    }

    private var restoring: Binding<Bool> {
        Binding(get: { backupToRestore != nil }, set: { if !$0 { backupToRestore = nil } })
    }

    private var showingMessage: Binding<Bool> {
        Binding(get: { backupMessage != nil }, set: { if !$0 { backupMessage = nil } })
    }

    private var liveActivity: Binding<Bool> {
        Binding(get: { model.state.showsLiveActivity }, set: { model.setShowsLiveActivity($0) })
    }

    private var sampleData: Binding<Bool> {
        Binding(get: { model.state.useSampleData }, set: { model.setUseSampleData($0) })
    }
}
