import ActivityKit
import Foundation

/// Keeps one Live Activity running with today's steps, plus the walk in progress if there is one.
/// iOS ends Live Activities after 8 hours, so a new one is started whenever the app finds it gone.
@MainActor
final class LiveActivityManager {
    private var activity: Activity<StrideActivityAttributes>?
    private var lastSent: StrideActivityAttributes.ContentState?
    private var lastSentAt = Date.distantPast

    init() {
        // Pick up an activity started on an earlier launch.
        activity = Activity<StrideActivityAttributes>.activities.first { $0.activityState == .active }
    }

    /// Shows `state`, starting an activity if needed. Updates at most every few seconds
    /// unless `force` is set, since iOS limits how often an app may update.
    func show(_ state: StrideActivityAttributes.ContentState, force: Bool = false) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // Shown as out of date if no update arrives for half an hour.
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(30 * 60))

        if let activity, activity.activityState == .active {
            guard state != lastSent, force || Date().timeIntervalSince(lastSentAt) >= 3 else { return }
            lastSent = state
            lastSentAt = Date()
            Task { await activity.update(content) }
        } else {
            activity = try? Activity.request(attributes: StrideActivityAttributes(), content: content, pushType: nil)
            lastSent = state
            lastSentAt = Date()
        }
    }

    /// Updates right away and waits for it, for background refreshes that end when this returns.
    func showNow(_ state: StrideActivityAttributes.ContentState) async {
        guard let activity, activity.activityState == .active else {
            show(state, force: true)
            return
        }
        lastSent = state
        lastSentAt = Date()
        await activity.update(ActivityContent(state: state, staleDate: Date().addingTimeInterval(30 * 60)))
    }

    func end() {
        guard let activity else { return }
        self.activity = nil
        lastSent = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
