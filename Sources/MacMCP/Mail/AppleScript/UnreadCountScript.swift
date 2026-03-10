enum UnreadCountScript {
    static func count(accountName: String?, mailboxName: String?) -> String {
        let safeAccount = accountName.map { InputValidation.escapeForAppleScript($0) }
        let safeMailbox = mailboxName.map { InputValidation.escapeForAppleScript($0) }

        if let acct = safeAccount, let mbox = safeMailbox {
            // Specific mailbox — use escapeForJSON for JSON-safe account/mailbox names
            return """
            \(AppleScriptHelpers.escapeForJSON)

            tell application "Mail"
                set acctRef to account "\(acct)"
                set mb to mailbox "\(mbox)" of acctRef
                set cnt to unread count of mb
                set safeAcct to my escapeForJSON(name of acctRef)
                set safeMbox to my escapeForJSON(name of mb)
                return "{\\"unreadCount\\": " & cnt & ", \\"accountName\\": \\"" & safeAcct & "\\", \\"mailboxName\\": \\"" & safeMbox & "\\"}"
            end tell
            """
        } else if let acct = safeAccount {
            // All mailboxes in an account
            return """
            \(AppleScriptHelpers.escapeForJSON)

            tell application "Mail"
                set acctRef to account "\(acct)"
                set totalUnread to 0
                set mboxes to every mailbox of acctRef
                set jsonDetails to "["
                set isFirst to true
                repeat with mb in mboxes
                    set cnt to unread count of mb
                    set totalUnread to totalUnread + cnt
                    if cnt > 0 then
                        if not isFirst then set jsonDetails to jsonDetails & ","
                        set isFirst to false
                        set mbName to my escapeForJSON(name of mb)
                        set jsonDetails to jsonDetails & "{\\"mailbox\\": \\"" & mbName & "\\", \\"count\\": " & cnt & "}"
                    end if
                end repeat
                set jsonDetails to jsonDetails & "]"
                set safeAcct to my escapeForJSON(name of acctRef)
                return "{\\"unreadCount\\": " & totalUnread & ", \\"accountName\\": \\"" & safeAcct & "\\", \\"breakdown\\": " & jsonDetails & "}"
            end tell
            """
        } else {
            // All accounts
            return """
            \(AppleScriptHelpers.escapeForJSON)

            tell application "Mail"
                set totalUnread to 0
                set jsonDetails to "["
                set isFirst to true
                set accts to every account
                repeat with a in accts
                    set acctUnread to 0
                    set mboxes to every mailbox of a
                    repeat with mb in mboxes
                        set acctUnread to acctUnread + (unread count of mb)
                    end repeat
                    set totalUnread to totalUnread + acctUnread
                    if acctUnread > 0 then
                        if not isFirst then set jsonDetails to jsonDetails & ","
                        set isFirst to false
                        set acctName to my escapeForJSON(name of a)
                        set jsonDetails to jsonDetails & "{\\"account\\": \\"" & acctName & "\\", \\"count\\": " & acctUnread & "}"
                    end if
                end repeat
                set jsonDetails to jsonDetails & "]"
                return "{\\"unreadCount\\": " & totalUnread & ", \\"breakdown\\": " & jsonDetails & "}"
            end tell
            """
        }
    }
}
