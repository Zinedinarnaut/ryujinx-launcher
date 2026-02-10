import WidgetKit
import SwiftUI

@main
struct RyjinxLauncherWidgets: WidgetBundle {
    var body: some Widget {
        RecentlyPlayedWidget()
        TopPlayedWidget()
        QuickLaunchWidget()
    }
}
