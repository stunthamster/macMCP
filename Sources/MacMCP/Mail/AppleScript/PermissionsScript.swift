enum PermissionsScript {
    static func checkMailAccess() -> String {
        """
        tell application "Mail"
            set acctCount to count of accounts
            return "{\\"status\\": \\"ok\\", \\"accountCount\\": " & acctCount & "}"
        end tell
        """
    }
}
