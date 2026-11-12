//
//  Redactor.swift
//  LetterLens-iOS
//

import Foundation

/// Deterministic redaction, then an optional on-device pass for names the rules missed.
/// Dates are left in the text. They are needed for the deadline quote.
///
/// The fuzzy pass is the hook for a later on-device model. The default pass does nothing
/// and must not send text off the device.
protocol RedactionFuzzyPass {
    func redactRemaining(_ result: RedactionResult) -> RedactionResult
}

struct NoOpRedactionFuzzyPass: RedactionFuzzyPass {
    func redactRemaining(_ result: RedactionResult) -> RedactionResult { result }
}

struct Redactor {
    var fuzzyPass: any RedactionFuzzyPass = NoOpRedactionFuzzyPass()

    func redact(_ text: String) -> RedactionResult {
        fuzzyPass.redactRemaining(Self.deterministic(text))
    }

    private static func deterministic(_ text: String) -> RedactionResult {
        let spans = resolve(candidates(in: text), in: text)
        return apply(spans, to: text)
    }

    private struct Span {
        var range: Range<String.Index>
        var kind: Kind
        var priority: Int
    }

    private enum Kind: String {
        case name = "NAME"
        case address = "ADDRESS"
        case postcode = "POSTCODE"
        case phone = "PHONE"
        case email = "EMAIL"
        case link = "LINK"
        case ni = "NI"
        case sortCode = "SORTCODE"
        case account = "ACCOUNT"
        case card = "CARD"
        case ref = "REF"
    }

    private static let genericNames: Set<String> = [
        "sir", "madam", "sir or madam", "customer", "colleague", "resident",
        "occupier", "householder", "sir/madam", "all",
    ]

    private static func candidates(in text: String) -> [Span] {
        var spans: [Span] = []
        spans += detectorSpans(in: text)
        spans += regexSpans(in: text)
        return spans
    }

    private static func detectorSpans(in text: String) -> [Span] {
        let types: NSTextCheckingResult.CheckingType = [.phoneNumber, .link, .address]
        guard let detector = try? NSDataDetector(types: types.rawValue) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        var spans: [Span] = []
        detector.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let match, let swiftRange = Range(match.range, in: text) else { return }
            switch match.resultType {
            case .phoneNumber:
                spans.append(Span(range: swiftRange, kind: .phone, priority: 65))
            case .link:
                let scheme = match.url?.scheme?.lowercased()
                if scheme == "mailto" {
                    spans.append(Span(range: swiftRange, kind: .email, priority: 100))
                } else {
                    spans.append(Span(range: swiftRange, kind: .link, priority: 60))
                }
            case .address:
                spans.append(Span(range: swiftRange, kind: .address, priority: 40))
            default:
                break
            }
        }
        return spans
    }

    private static func regexSpans(in text: String) -> [Span] {
        var spans: [Span] = []

        func add(_ pattern: String, kind: Kind, priority: Int, group: Int = 0, accept: ((String) -> Bool)? = nil) {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
            let nsText = text as NSString
            let full = NSRange(location: 0, length: nsText.length)
            for match in regex.matches(in: text, options: [], range: full) {
                let nsRange = match.range(at: group)
                guard nsRange.location != NSNotFound, let swiftRange = Range(nsRange, in: text) else { continue }
                let snippet = String(text[swiftRange])
                if let accept, !accept(snippet) { continue }
                spans.append(Span(range: swiftRange, kind: kind, priority: priority))
            }
        }

        add(
            #"[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}"#,
            kind: .email,
            priority: 100
        )
        add(
            #"(?i)\b(?:https?://|www\.)[^\s<>()]+"#,
            kind: .link,
            priority: 60,
            accept: { snippet in
                var trimmed = snippet
                while let last = trimmed.last, ",.;:)]".contains(last) {
                    trimmed.removeLast()
                }
                return trimmed.count > 4
            }
        )
        add(
            #"(?i)\b([A-Z]{2})\s*(\d{2})\s*(\d{2})\s*(\d{2})\s*([A-D])\b"#,
            kind: .ni,
            priority: 90
        )
        add(
            #"(?i)\b([A-Z]{1,2}\d[A-Z\d]?)\s*(\d[A-Z]{2})\b"#,
            kind: .postcode,
            priority: 85
        )
        add(
            #"\b\d{2}-\d{2}-\d{2}\b"#,
            kind: .sortCode,
            priority: 80
        )
        add(
            #"(?i)\bsort\s*code\b[:\s]*(\d{2}[-\s]?\d{2}[-\s]?\d{2})\b"#,
            kind: .sortCode,
            priority: 80,
            group: 1
        )
        add(
            #"\b(?:\d{4}[ -]){3}\d{4}\b"#,
            kind: .card,
            priority: 75
        )
        add(
            #"\b\d{13,19}\b"#,
            kind: .card,
            priority: 75
        )
        add(
            #"(?i)\b(?:account(?:\s+number)?|a/c)\b[:\s#]*(\d{6,10})\b"#,
            kind: .account,
            priority: 70,
            group: 1
        )
        add(
            #"(?<!\d)(?:\+44[\s-]?\d(?:[\s-]?\d){8,10}|0\d(?:[\s-]?\d){8,10})(?!\d)"#,
            kind: .phone,
            priority: 65
        )
        add(
            #"(?i)\b(?:our\s+reference|reference|ref\.?|customer\s+reference|account\s+ref(?:erence)?)\b[:\s]*([A-Z0-9][A-Z0-9\-/]{4,})"#,
            kind: .ref,
            priority: 55,
            group: 1
        )
        add(
            #"(?i)\b(?=[A-Z0-9]*\d)(?=[A-Z0-9]*[A-Z])[A-Z0-9]{8,}\b"#,
            kind: .ref,
            priority: 50
        )
        add(
            #"(?i)\b(?:dear|hello|hi)\s+([^,\n]{1,80}?)(?=\s*[,.\n])"#,
            kind: .name,
            priority: 45,
            group: 1,
            accept: { snippet in
                let name = snippet.trimmingCharacters(in: .whitespacesAndNewlines)
                return !genericNames.contains(name.lowercased()) && name.count >= 2
            }
        )
        add(
            #"(?i)\[(NAME|OFFICER NAME|ADDRESS LINE \d+|POSTCODE|PHONE|NI NUMBER|ACCOUNT NUMBER|ACCOUNT REF|SORT CODE|EMAIL|REF|BANK ADDRESS|COUNCIL ADDRESS|HMRC OFFICE ADDRESS|PO BOX)\]"#,
            kind: .ref,
            priority: 35,
            accept: { snippet in
                // The kind is refined below from the placeholder word. Keep the span.
                !snippet.isEmpty
            }
        )

        return spans.map { span in
            guard span.kind == .ref, text[span.range].hasPrefix("[") else { return span }
            return Span(range: span.range, kind: kind(forPlaceholder: String(text[span.range])), priority: span.priority)
        }
    }

    private static func kind(forPlaceholder placeholder: String) -> Kind {
        let word = placeholder.trimmingCharacters(in: CharacterSet(charactersIn: "[]")).lowercased()
        if word.contains("name") { return .name }
        if word.contains("postcode") { return .postcode }
        if word.contains("phone") { return .phone }
        if word.contains("email") { return .email }
        if word.contains("sort") { return .sortCode }
        if word.contains("ni") { return .ni }
        if word.contains("account") { return .account }
        if word.contains("address") || word.contains("po box") { return .address }
        return .ref
    }

    /// Higher priority wins. A lower-priority span that contains a winner is split around it.
    private static func resolve(_ spans: [Span], in text: String) -> [Span] {
        let tidied = spans.map { span -> Span in
            guard span.kind == .link || span.kind == .email || span.kind == .phone else { return span }
            return Span(
                range: trimmingPunctuation(span.range, in: text),
                kind: span.kind,
                priority: span.priority
            )
        }
        let sorted = tidied.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            let left = text.distance(from: lhs.range.lowerBound, to: lhs.range.upperBound)
            let right = text.distance(from: rhs.range.lowerBound, to: rhs.range.upperBound)
            if left != right { return left > right }
            return lhs.range.lowerBound < rhs.range.lowerBound
        }

        var accepted: [Span] = []
        for candidate in sorted {
            var pieces = [candidate.range]
            for existing in accepted {
                pieces = pieces.flatMap { subtract(existing.range, from: $0) }
            }
            for piece in pieces {
                let snippet = text[piece].trimmingCharacters(in: .whitespacesAndNewlines)
                let minimum = candidate.kind == .name ? 2 : 3
                guard snippet.count >= minimum else { continue }
                accepted.append(Span(range: piece, kind: candidate.kind, priority: candidate.priority))
            }
        }
        return accepted.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    private static func trimmingPunctuation(
        _ range: Range<String.Index>,
        in text: String
    ) -> Range<String.Index> {
        var end = range.upperBound
        while end > range.lowerBound {
            let previous = text.index(before: end)
            if ",.;:)]".contains(text[previous]) {
                end = previous
            } else {
                break
            }
        }
        return range.lowerBound..<end
    }

    private static func subtract(
        _ taken: Range<String.Index>,
        from source: Range<String.Index>
    ) -> [Range<String.Index>] {
        guard source.overlaps(taken) else { return [source] }
        var pieces: [Range<String.Index>] = []
        if source.lowerBound < taken.lowerBound {
            pieces.append(source.lowerBound..<taken.lowerBound)
        }
        if taken.upperBound < source.upperBound {
            pieces.append(taken.upperBound..<source.upperBound)
        }
        return pieces
    }

    private static func apply(_ spans: [Span], to text: String) -> RedactionResult {
        var map = RedactionMap()
        var counts: [Kind: Int] = [:]
        var result = ""
        var cursor = text.startIndex
        for span in spans where span.range.lowerBound >= cursor {
            result += text[cursor..<span.range.lowerBound]
            let original = String(text[span.range])
            let number = (counts[span.kind] ?? 0) + 1
            counts[span.kind] = number
            let token = "[\(span.kind.rawValue)_\(number)]"
            map.entries.append(RedactionMap.Entry(token: token, original: original, kind: span.kind.rawValue))
            result += token
            cursor = span.range.upperBound
        }
        result += text[cursor...]
        return RedactionResult(text: result, map: map)
    }
}
