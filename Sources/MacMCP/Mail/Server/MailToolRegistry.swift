import MCP

enum ToolRegistry {
    static func allTools() -> [Tool] {
        [
            Tool(
                name: "check_permissions",
                description: "Check if the MCP server has permission to control Mail.app. Run this first to diagnose any access issues.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([:])
                ])
            ),
            Tool(
                name: "mail_list_accounts",
                description: "List all email accounts configured in Mail.app.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([:])
                ])
            ),
            Tool(
                name: "mail_list_mailboxes",
                description: "List mailboxes (folders) for a specific email account.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "account_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the email account (from mail_list_accounts)")
                        ])
                    ]),
                    "required": .array([.string("account_name")])
                ])
            ),
            Tool(
                name: "mail_list_messages",
                description: "List messages in a mailbox with pagination. Returns message summaries with a short preview snippet. Use the preview to triage which emails need full reading. Messages are ordered most-recent first.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "account_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the email account")
                        ]),
                        "mailbox_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the mailbox (e.g., 'INBOX')")
                        ]),
                        "limit": .object([
                            "type": .string("integer"),
                            "description": .string("Number of messages to return (default 25, max 100)")
                        ]),
                        "offset": .object([
                            "type": .string("integer"),
                            "description": .string("Number of messages to skip (default 0)")
                        ])
                    ]),
                    "required": .array([.string("account_name"), .string("mailbox_name")])
                ])
            ),
            Tool(
                name: "mail_read_message",
                description: "Read the full content of a specific email message. Returns body text, recipients, and metadata. IMPORTANT: To keep context manageable, read and fully process one email at a time — complete any actions (e.g. creating reminders) for each email before reading the next.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "account_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the email account")
                        ]),
                        "mailbox_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the mailbox")
                        ]),
                        "message_id": .object([
                            "type": .string("integer"),
                            "description": .string("Message ID (from mail_list_messages)")
                        ])
                    ]),
                    "required": .array([.string("account_name"), .string("mailbox_name"), .string("message_id")])
                ])
            ),
            Tool(
                name: "mail_search_messages",
                description: "Search for messages by subject, sender, or read status. At least one search criterion must be provided. Returns message summaries.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "account_name": .object([
                            "type": .string("string"),
                            "description": .string("Limit search to this account (optional)")
                        ]),
                        "mailbox_name": .object([
                            "type": .string("string"),
                            "description": .string("Limit search to this mailbox (optional, requires account_name)")
                        ]),
                        "subject_contains": .object([
                            "type": .string("string"),
                            "description": .string("Search for messages whose subject contains this text")
                        ]),
                        "sender_contains": .object([
                            "type": .string("string"),
                            "description": .string("Search for messages from senders containing this text")
                        ]),
                        "is_unread": .object([
                            "type": .string("boolean"),
                            "description": .string("If true, only return unread messages")
                        ]),
                        "limit": .object([
                            "type": .string("integer"),
                            "description": .string("Maximum results to return (default 25, max 100)")
                        ])
                    ])
                ])
            ),
            Tool(
                name: "mail_set_flag",
                description: "Set or clear a flag on a message. Flag colors: 0=Red, 1=Orange, 2=Yellow, 3=Green, 4=Blue, 5=Purple, 6=Gray. Use -1 to clear the flag.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "account_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the email account")
                        ]),
                        "mailbox_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the mailbox")
                        ]),
                        "message_id": .object([
                            "type": .string("integer"),
                            "description": .string("Message ID (from mail_list_messages or mail_search_messages)")
                        ]),
                        "flag_index": .object([
                            "type": .string("integer"),
                            "description": .string("Flag color: 0=Red, 1=Orange, 2=Yellow, 3=Green, 4=Blue, 5=Purple, 6=Gray, -1=Clear")
                        ])
                    ]),
                    "required": .array([.string("account_name"), .string("mailbox_name"), .string("message_id"), .string("flag_index")])
                ])
            ),
            Tool(
                name: "mail_get_unread_count",
                description: "Get the count of unread messages. Can be scoped to a specific account and/or mailbox, or returns totals across all accounts.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "account_name": .object([
                            "type": .string("string"),
                            "description": .string("Limit to this account (optional)")
                        ]),
                        "mailbox_name": .object([
                            "type": .string("string"),
                            "description": .string("Limit to this mailbox (optional, requires account_name)")
                        ])
                    ])
                ])
            ),
        ]
    }
}
