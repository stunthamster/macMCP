@testable import MacMCP
import Testing

@Suite("sanitizeJSON")
struct SanitizeJSONTests {
    @Test("Passes through valid JSON unchanged")
    func validJSON() {
        let input = #"{"key": "value", "num": 42, "arr": [true, false, null]}"#
        #expect(AppleScriptRunner.sanitizeJSON(input) == input)
    }

    @Test("Escapes raw newline")
    func rawNewline() {
        let input = "{\"body\": \"line1\nline2\"}"
        let expected = #"{"body": "line1\nline2"}"#
        #expect(AppleScriptRunner.sanitizeJSON(input) == expected)
    }

    @Test("Escapes raw carriage return")
    func rawCarriageReturn() {
        let input = "{\"body\": \"line1\rline2\"}"
        let expected = #"{"body": "line1\rline2"}"#
        #expect(AppleScriptRunner.sanitizeJSON(input) == expected)
    }

    @Test("Escapes raw tab")
    func rawTab() {
        let input = "{\"body\": \"col1\tcol2\"}"
        let expected = #"{"body": "col1\tcol2"}"#
        #expect(AppleScriptRunner.sanitizeJSON(input) == expected)
    }

    @Test("Preserves already-escaped sequences")
    func alreadyEscaped() {
        let input = #"{"body": "line1\nline2\ttab\\slash\"quote"}"#
        #expect(AppleScriptRunner.sanitizeJSON(input) == input)
    }

    @Test("Escapes null byte")
    func nullByte() {
        let input = "{\"body\": \"before\u{0000}after\"}"
        let expected = #"{"body": "before\u0000after"}"#
        #expect(AppleScriptRunner.sanitizeJSON(input) == expected)
    }

    @Test("Escapes DEL character U+007F")
    func delCharacter() {
        let input = "{\"body\": \"before\u{007F}after\"}"
        let expected = #"{"body": "before\u007Fafter"}"#
        #expect(AppleScriptRunner.sanitizeJSON(input) == expected)
    }

    @Test("Escapes U+2028 and U+2029 line/paragraph separators")
    func lineSeparators() {
        let input = "{\"body\": \"before\u{2028}mid\u{2029}after\"}"
        let expected = #"{"body": "before\u2028mid\u2029after"}"#
        #expect(AppleScriptRunner.sanitizeJSON(input) == expected)
    }

    @Test("Handles newline fused with combining grapheme joiner U+034F")
    func graphemeClusterFusion() {
        // This is the exact bug scenario: LF followed by combining grapheme joiner.
        // AppleScript sees "\n\u{034F}" as a single grapheme cluster and misses it.
        // Swift's unicodeScalars iteration sees them separately.
        let input = "{\"body\": \"hello\n\u{034F}world\"}"
        let expected = "{\"body\": \"hello\\n\u{034F}world\"}"
        #expect(AppleScriptRunner.sanitizeJSON(input) == expected)
    }

    @Test("Handles multiple control characters in sequence")
    func multipleControlChars() {
        let input = "{\"v\": \"a\n\r\tb\"}"
        let expected = #"{"v": "a\n\r\tb"}"#
        #expect(AppleScriptRunner.sanitizeJSON(input) == expected)
    }

    @Test("Empty string passes through")
    func emptyString() {
        #expect(AppleScriptRunner.sanitizeJSON("") == "")
    }

    @Test("Escapes form feed and other C0 control characters")
    func otherControlCharacters() {
        // Form feed (0x0C), vertical tab (0x0B), bell (0x07)
        let input = "{\"v\": \"\u{0C}\u{0B}\u{07}\"}"
        let expected = #"{"v": "\u000C\u000B\u0007"}"#
        #expect(AppleScriptRunner.sanitizeJSON(input) == expected)
    }

    @Test("Trailing backslash does not crash")
    func trailingBackslash() {
        // Edge case: a trailing backslash (malformed JSON, but should not crash)
        let input = #"{"v": "test\"#
        let result = AppleScriptRunner.sanitizeJSON(input)
        #expect(result == input)
    }
}
