//
//  RedactionAttributedText.swift
//  LetterLens-iOS
//
//  One selectable string. Tokens, or the details put back in their place, are chips.
//  AttributedString can fill a run; it cannot round that fill. The chip colour is the fill.

import SwiftUI

enum RedactionAttributedText {
    static func make(text: String, map: RedactionMap, reinsert: Bool) -> AttributedString {
        var result = AttributedString()
        for segment in ScriptReinsertion.segments(in: text, map: map, reinsert: reinsert) {
            result += segment.isChip ? chip(segment.text) : body(segment.text)
        }
        return result
    }

    /// Chips only. The caller's own font and colour cover the rest, so this
    /// scales with whatever text style the surrounding view already set.
    static func inline(text: String, map: RedactionMap, reinsert: Bool) -> AttributedString {
        var result = AttributedString()
        for segment in ScriptReinsertion.segments(in: text, map: map, reinsert: reinsert) {
            result += segment.isChip ? inlineChip(segment.text) : AttributedString(segment.text)
        }
        return result
    }

    private static func inlineChip(_ text: String) -> AttributedString {
        var run = AttributedString(text)
        var attributes = AttributeContainer()
        attributes.foregroundColor = LLColor.deviceInk
        attributes.backgroundColor = LLColor.deviceTint
        run.mergeAttributes(attributes)
        return run
    }

    private static func body(_ text: String) -> AttributedString {
        var run = AttributedString(text)
        var attributes = AttributeContainer()
        attributes.font = LLFont.body
        attributes.foregroundColor = LLColor.ink
        run.mergeAttributes(attributes)
        return run
    }

    private static func chip(_ text: String) -> AttributedString {
        var run = AttributedString(text)
        var attributes = AttributeContainer()
        attributes.font = .subheadline.weight(.semibold)
        attributes.foregroundColor = LLColor.deviceInk
        attributes.backgroundColor = LLColor.deviceTint
        run.mergeAttributes(attributes)
        return run
    }
}
