enum FlagScript {
    /// Set or clear a flag on a message.
    /// flagIndex: 0=Red, 1=Orange, 2=Yellow, 3=Green, 4=Blue, 5=Purple, 6=Gray, -1=Clear
    static func setFlag(accountName: String, mailboxName: String, messageId: Int, flagIndex: Int) -> String {
        let safeAccount = InputValidation.escapeForAppleScript(accountName)
        let safeMailbox = InputValidation.escapeForAppleScript(mailboxName)

        return """
        tell application "Mail"
            set mb to mailbox "\(safeMailbox)" of account "\(safeAccount)"
            set msg to (first message of mb whose id is \(messageId))
            set flag index of msg to \(flagIndex)
            return "ok"
        end tell
        """
    }
}
