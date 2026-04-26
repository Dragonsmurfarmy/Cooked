//
//  Item.swift
//  Cooked
//
//  Created by Tomáš Kříž on 26.04.2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
