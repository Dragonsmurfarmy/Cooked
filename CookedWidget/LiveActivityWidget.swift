//
//  LiveActivityWidget.swift
//  Cooked
//
//  Created by Tomáš Kříž on 22.04.2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TimerLiveActivityWidget: Widget {
    
    let label: LocalizedStringKey = "widget.text"
    
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            
            // LOCK SCREEN
            VStack(alignment: .leading) {
                HStack(spacing: 8) {
                    Spacer()

                    Text(label)
                        .font(.title)
                        .fontWeight(.semibold)
                        .lineLimit(1) // Force text to be on 1 line
                        .minimumScaleFactor(0.5)
                    
                    Text(context.state.endDate, style: .timer)
                        .font(.title) 
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .padding(.horizontal)
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
