//
//  LiveActivityWidget.swift
//  Cooked
//
//  Created by Tomáš Kříž on 29.04.2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TimerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            
            // LOCK SCREEN
            VStack (alignment: .leading){
                HStack(spacing: 16){
                    
                    Spacer()

                    Text("widget.text")
                        .font(.title)
                        .fontWeight(.semibold)
                    
                    Text(context.state.endDate, style: .timer)
                        .font(.title)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
            }

        } dynamicIsland: { context in
            
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.endDate, style: .timer)
                        .font(.title2)
                }

            } compactLeading: {
                EmptyView()
            } compactTrailing: {
                Text(context.state.endDate, style: .timer)
            } minimal: {
                EmptyView()
            }
        }
    }
}
