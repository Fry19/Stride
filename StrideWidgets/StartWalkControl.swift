import AppIntents
import SwiftUI
import WidgetKit

/// A Control Center and Lock Screen button that starts a walk. It can also go on the Action Button.
@available(iOS 18.0, *)
struct StartWalkControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.fry19.stride.start-walk") {
            ControlWidgetButton(action: StartWalkIntent()) {
                Label("Start a Walk", systemImage: "figure.walk")
            }
        }
        .displayName("Start a Walk")
        .description("Starts a walk in Stride.")
    }
}
