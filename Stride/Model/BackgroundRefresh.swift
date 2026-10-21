import BackgroundTasks
import Foundation

/// Asks iOS to wake Stride now and then in the background to update the Live Activity.
/// iOS decides when, usually every 15 to 60 minutes, more often for apps used a lot.
enum BackgroundRefresh {
    /// Also listed under BGTaskSchedulerPermittedIdentifiers in Config/Stride-Info.plist.
    static let identifier = "com.fry19.stride.refresh"

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date().addingTimeInterval(15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Couldn't schedule a background refresh: \(error)")
        }
    }
}
