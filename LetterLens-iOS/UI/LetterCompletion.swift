//
//  LetterCompletion.swift
//  LetterLens-iOS
//
//  "Mark done" for this launch. LetterRecord has no field for it, and the
//  card schema stays unchanged, so this is not written to the store.

import Foundation
import Observation

@MainActor
@Observable
final class LetterCompletion {
    private(set) var doneIDs: Set<UUID>

    init(doneIDs: Set<UUID> = []) {
        self.doneIDs = doneIDs
    }

    func isDone(_ id: UUID) -> Bool {
        doneIDs.contains(id)
    }

    func setDone(_ id: UUID, isDone: Bool) {
        var updated = doneIDs
        if isDone {
            updated.insert(id)
        } else {
            updated.remove(id)
        }
        doneIDs = updated
    }

    func toggle(_ id: UUID) {
        setDone(id, isDone: !isDone(id))
    }
}
