import ActivityKit
import CoreLocation
import CoreMotion
import StrideCore
import SwiftUI
import UserNotifications

/// Everything Stride depends on, at a glance: permissions, where today's steps came from,
/// and whether background updates are getting through.
struct StatusView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var healthNeedsToAsk = false
    @State private var notifications: UNAuthorizationStatus = .notDetermined
    @State private var location: CLAuthorizationStatus = .notDetermined
    @State private var preciseLocation = true
    @State private var backgroundRefresh: UIBackgroundRefreshStatus = .available
    @State private var lowPower = false

    var body: some View {
        Form {
            Section {
                health
                motion
            } header: {
                Text("Steps")
            } footer: {
                Text("Stride takes the higher of Apple Health and your iPhone's motion sensors for each day, so a gap in one is covered by the other.")
            }

            Section {
                StatusRow(symbol: "location.fill", title: "Location", detail: locationDetail, level: locationLevel)
                StatusRow(symbol: "bell.badge.fill", title: "Notifications", detail: notificationDetail,
                          level: notifications == .denied ? .warning : notifications == .notDetermined ? .neutral : .ok)
            } header: {
                Text("Walks & nudges")
            } footer: {
                Text("Location draws your route on walks and finds journeys near you. Notifications are only for the evening nudge.")
            }

            Section {
                liveActivityRow
                backgroundRow
                if lowPower {
                    StatusRow(symbol: "battery.25percent", title: "Low Power Mode is on",
                              detail: "iOS pauses background updates until it's off.", level: .warning)
                }
            } header: {
                Text("Dynamic Island")
            }

            Section {
                LabeledContent("XP counted since", value: StrideFormat.date(model.state.startDay))
                LabeledContent("Days with steps", value: model.state.activity.filter { $0.steps > 0 }.count.formatted())
                LabeledContent("Walks saved", value: model.walks.count.formatted())
                LabeledContent("Journeys started", value: model.state.journeys.count.formatted())
                LabeledContent("Total XP", value: StrideFormat.xp(model.summary.totalXP))
            } header: {
                Text("Your data")
            }

            if needsSettings {
                Section {
                    Button("Open Stride in Settings") {
                        openURL(URL(string: UIApplication.openSettingsURLString)!)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Status")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await reload() } }
        }
    }

    // MARK: - Rows

    @ViewBuilder private var health: some View {
        if !model.isHealthAvailable {
            StatusRow(symbol: "heart.fill", title: "Apple Health", detail: "Not available on this device.", level: .warning)
        } else if let error = model.healthError {
            StatusRow(symbol: "heart.fill", title: "Apple Health", detail: "Couldn't be read: \(error)", level: .problem)
        } else if healthNeedsToAsk {
            StatusRow(symbol: "heart.fill", title: "Apple Health", detail: "Stride hasn't asked for access yet.",
                      level: .warning) {
                Button("Allow") { Task { await model.askForHealthAccess(); await reload() } }
            }
        } else if let read = model.healthReadAt, let steps = model.healthStepsToday {
            let motionToday = model.summary.todayResult.steps
            if steps == 0 && motionToday > 200 {
                StatusRow(symbol: "heart.fill", title: "Apple Health",
                          detail: "Shows no steps today while your iPhone counted \(motionToday.formatted()). Check that Stride may read Steps: open the Health app, tap your profile picture, then Apps → Stride.",
                          level: .warning)
            } else {
                StatusRow(symbol: "heart.fill", title: "Apple Health", level: .ok) {
                    Text("\(steps.formatted()) steps today, read ") + Text(read, style: .relative) + Text(" ago")
                }
            }
        } else {
            StatusRow(symbol: "heart.fill", title: "Apple Health", detail: "Not read yet.", level: .neutral)
        }
    }

    @ViewBuilder private var motion: some View {
        switch CMPedometer.authorizationStatus() {
        case .denied, .restricted:
            StatusRow(symbol: "figure.walk.motion", title: "Motion & Fitness",
                      detail: "Turned off, so steps only update when Health does, not live.", level: .problem)
        case .notDetermined:
            StatusRow(symbol: "figure.walk.motion", title: "Motion & Fitness", detail: "Not asked yet.", level: .neutral)
        default:
            if !CMPedometer.isStepCountingAvailable() {
                StatusRow(symbol: "figure.walk.motion", title: "Motion & Fitness",
                          detail: "This device can't count steps.", level: .warning)
            } else if model.isCountingLive {
                StatusRow(symbol: "figure.walk.motion", title: "Motion & Fitness", level: .ok) {
                    if let last = model.lastLiveStep {
                        Text("Counting live. Last step ") + Text(last, style: .relative) + Text(" ago")
                    } else {
                        Text("Counting live")
                    }
                }
            } else {
                StatusRow(symbol: "figure.walk.motion", title: "Motion & Fitness", detail: "Allowed", level: .ok)
            }
        }
    }

    @ViewBuilder private var liveActivityRow: some View {
        let enabled = ActivityAuthorizationInfo().areActivitiesEnabled
        if !enabled {
            StatusRow(symbol: "platter.filled.top.iphone", title: "Live Activities",
                      detail: "Turned off for Stride in Settings.", level: .problem)
        } else if !model.state.showsLiveActivity {
            StatusRow(symbol: "platter.filled.top.iphone", title: "Live Activities",
                      detail: "Off in Stride's settings. Walks still show.", level: .neutral)
        } else {
            StatusRow(symbol: "platter.filled.top.iphone", title: "Live Activities",
                      detail: model.isLiveActivityRunning ? "Showing today's steps." : "Starts the next time Stride opens.",
                      level: model.isLiveActivityRunning ? .ok : .neutral)
        }
    }

    @ViewBuilder private var backgroundRow: some View {
        switch backgroundRefresh {
        case .denied, .restricted:
            StatusRow(symbol: "arrow.triangle.2.circlepath", title: "Background App Refresh",
                      detail: "Off, so the Dynamic Island only updates while Stride is open.", level: .problem)
        default:
            StatusRow(symbol: "arrow.triangle.2.circlepath", title: "Background updates", level: .ok) {
                if let last = model.lastBackgroundRefresh {
                    Text("Last one ") + Text(last, style: .relative) + Text(" ago. iOS decides how often.")
                } else {
                    Text("None yet. iOS decides when, usually every 15 to 60 minutes.")
                }
            }
        }
    }

    // MARK: - Details

    private var locationDetail: String {
        switch location {
        case .authorizedAlways, .authorizedWhenInUse:
            return preciseLocation ? "Allowed" : "Allowed, but Precise Location is off, so routes are rough."
        case .denied, .restricted: return "Turned off, so walks have no route or GPS distance."
        default: return "Asked for on your first walk."
        }
    }

    private var locationLevel: StatusLevel {
        switch location {
        case .authorizedAlways, .authorizedWhenInUse: return preciseLocation ? .ok : .warning
        case .denied, .restricted: return .warning
        default: return .neutral
        }
    }

    private var notificationDetail: String {
        switch notifications {
        case .authorized, .provisional, .ephemeral: return "Allowed"
        case .denied: return "Turned off, so the evening nudge can't appear."
        default: return "Asked for when you turn on the evening nudge."
        }
    }

    private var needsSettings: Bool {
        notifications == .denied || [.denied, .restricted].contains(location) || !preciseLocation
            || [.denied, .restricted].contains(CMPedometer.authorizationStatus())
            || backgroundRefresh != .available || !ActivityAuthorizationInfo().areActivitiesEnabled
    }

    private func reload() async {
        healthNeedsToAsk = await model.healthNeedsToAsk()
        notifications = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        let manager = CLLocationManager()
        location = manager.authorizationStatus
        preciseLocation = manager.accuracyAuthorization == .fullAccuracy
        backgroundRefresh = UIApplication.shared.backgroundRefreshStatus
        lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    }
}

/// How a status row is doing, shown as a small badge.
enum StatusLevel {
    case ok, neutral, warning, problem

    var color: Color {
        switch self {
        case .ok: return Theme.live
        case .neutral: return Theme.textTertiary
        case .warning: return Color(hex: 0xFFC247)
        case .problem: return Theme.ember
        }
    }

    var badge: String {
        switch self {
        case .ok: return "checkmark.circle.fill"
        case .neutral: return "minus.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .problem: return "xmark.octagon.fill"
        }
    }
}

/// One line of the status screen: a coloured symbol, a title, and what it means.
struct StatusRow<Action: View>: View {
    let symbol: String
    let title: String
    let level: StatusLevel
    private let detail: AnyView
    private let action: Action

    init(symbol: String, title: String, detail: String, level: StatusLevel, @ViewBuilder action: () -> Action) {
        self.symbol = symbol
        self.title = title
        self.level = level
        self.detail = AnyView(Text(detail))
        self.action = action()
    }

    init<Detail: View>(symbol: String, title: String, level: StatusLevel, @ViewBuilder detail: () -> Detail) where Action == EmptyView {
        self.symbol = symbol
        self.title = title
        self.level = level
        self.detail = AnyView(detail())
        self.action = EmptyView()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: level.badge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(level.color)
                        .background(Circle().fill(Theme.background).padding(1))
                        .offset(x: 4, y: 4)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                detail
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            action
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
    }
}

extension StatusRow where Action == EmptyView {
    init(symbol: String, title: String, detail: String, level: StatusLevel) {
        self.init(symbol: symbol, title: title, detail: detail, level: level) { EmptyView() }
    }
}
