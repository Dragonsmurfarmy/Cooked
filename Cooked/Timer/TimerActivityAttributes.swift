//
//  TimerActivityAttributes.swift
//  Cooked
//
//  Created by Tomáš Kříž on 28.04.2026.
//

import ActivityKit
import Foundation

struct TimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var endDate: Date
    }

    var title: String
}
