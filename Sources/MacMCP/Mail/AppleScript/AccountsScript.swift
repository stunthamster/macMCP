enum AccountsScript {
    static func listAll() -> String {
        """
        \(AppleScriptHelpers.escapeForJSON)

        tell application "Mail"
            set jsonResult to "["
            set accts to every account
            set isFirst to true
            repeat with a in accts
                if not isFirst then set jsonResult to jsonResult & ","
                set isFirst to false

                set acctName to my escapeForJSON(name of a)
                set acctUser to my escapeForJSON(user name of a)
                set acctEnabled to enabled of a
                set acctEmails to email addresses of a

                set emailJson to "["
                set emailFirst to true
                repeat with e in acctEmails
                    if not emailFirst then set emailJson to emailJson & ","
                    set emailFirst to false
                    set emailJson to emailJson & "\\"" & my escapeForJSON(e as string) & "\\""
                end repeat
                set emailJson to emailJson & "]"

                set jsonResult to jsonResult & "{\\"name\\": \\"" & acctName & "\\""
                set jsonResult to jsonResult & ", \\"userName\\": \\"" & acctUser & "\\""
                set jsonResult to jsonResult & ", \\"enabled\\": " & acctEnabled
                set jsonResult to jsonResult & ", \\"emailAddresses\\": " & emailJson
                set jsonResult to jsonResult & "}"
            end repeat
            set jsonResult to jsonResult & "]"
            return jsonResult
        end tell
        """
    }
}
