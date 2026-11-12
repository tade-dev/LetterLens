//
//  Item.swift
//  LetterLens-iOS
//
//  Created by BSTAR on 12/11/2026.
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
