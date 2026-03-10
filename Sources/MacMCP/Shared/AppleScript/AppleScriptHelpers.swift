/// Shared AppleScript helper functions prepended to scripts that handle user content.
enum AppleScriptHelpers {
    /// AppleScript handler to escape a string for safe JSON embedding.
    static let escapeForJSON = """
    on escapeForJSON(txt)
        set txt to replaceText(txt, "\\\\", "\\\\\\\\")
        set txt to replaceText(txt, "\\"", "\\\\\\"")
        set txt to replaceText(txt, return, "\\\\n")
        set txt to replaceText(txt, linefeed, "\\\\n")
        set txt to replaceText(txt, tab, "\\\\t")
        return txt
    end escapeForJSON

    on replaceText(sourceText, searchText, replacementText)
        set AppleScript's text item delimiters to searchText
        set textItems to text items of sourceText
        set AppleScript's text item delimiters to replacementText
        set sourceText to textItems as text
        set AppleScript's text item delimiters to ""
        return sourceText
    end replaceText
    """
}
