enum SearchScript {
    static func search(
        accountName: String?,
        mailboxName: String?,
        subjectContains: String?,
        senderContains: String?,
        isUnread: Bool?,
        limit: Int
    ) -> String {
        let safeAccount = accountName.map { InputValidation.escapeForAppleScript($0) }
        let safeMailbox = mailboxName.map { InputValidation.escapeForAppleScript($0) }
        let safeSubject = subjectContains.map { InputValidation.escapeForAppleScript($0) }
        let safeSender = senderContains.map { InputValidation.escapeForAppleScript($0) }

        // Build the whose clause
        var whoseParts: [String] = []
        if let subj = safeSubject {
            whoseParts.append("subject contains \"\(subj)\"")
        }
        if let unread = isUnread {
            whoseParts.append("read status is \(unread ? "false" : "true")")
        }

        let whoseClause: String
        if whoseParts.isEmpty {
            whoseClause = ""
        } else {
            whoseClause = " whose \(whoseParts.joined(separator: " and "))"
        }

        // Build the mailbox reference
        let mailboxRef: String
        if let acct = safeAccount, let mbox = safeMailbox {
            mailboxRef = "mailbox \"\(mbox)\" of account \"\(acct)\""
        } else if let acct = safeAccount {
            mailboxRef = "inbox of account \"\(acct)\""
        } else {
            mailboxRef = "inbox"
        }

        // Sender filtering done in loop (more reliable than compound whose)
        let senderFilter: String
        if let sender = safeSender {
            senderFilter = """
                    set sndrText to sender of m as string
                    if sndrText does not contain "\(sender)" then
                        set skipThis to true
                    end if
            """
        } else {
            senderFilter = ""
        }

        return """
        \(AppleScriptHelpers.escapeForJSON)

        tell application "Mail"
            set mb to \(mailboxRef)
            set allMsgs to (every message of mb\(whoseClause))
            set maxResults to \(limit)
            set resultCount to 0

            set jsonResult to "["
            set isFirst to true
            repeat with m in allMsgs
                if resultCount >= maxResults then exit repeat

                set skipThis to false
        \(senderFilter)

                if not skipThis then
                    if not isFirst then set jsonResult to jsonResult & ","
                    set isFirst to false
                    set resultCount to resultCount + 1

                    set subj to my escapeForJSON(subject of m)
                    set sndr to my escapeForJSON(sender of m)
                    set msgId to id of m
                    set isRead to read status of m
                    set isFlagged to flagged status of m

                    set dateRecv to date received of m
                    set dateStr to my escapeForJSON((dateRecv as «class isot» as string))

                    set jsonResult to jsonResult & "{\\"id\\": " & msgId
                    set jsonResult to jsonResult & ", \\"subject\\": \\"" & subj & "\\""
                    set jsonResult to jsonResult & ", \\"sender\\": \\"" & sndr & "\\""
                    set jsonResult to jsonResult & ", \\"dateReceived\\": \\"" & dateStr & "\\""
                    set jsonResult to jsonResult & ", \\"isRead\\": " & isRead
                    set jsonResult to jsonResult & ", \\"isFlagged\\": " & isFlagged
                    set jsonResult to jsonResult & "}"
                end if
            end repeat
            set jsonResult to jsonResult & "]"
            return jsonResult
        end tell
        """
    }
}
