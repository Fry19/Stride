import SwiftUI
import WidgetKit

@main
struct StrideWidgetsBundle: WidgetBundle {
    var body: some Widget {
        StrideLiveActivity()
        if #available(iOS 18.0, *) {
            StartWalkControl()
        }
    }
}
