import MCP

enum RemindersToolRegistry {
    static func allTools() -> [Tool] {
        [
            // P1: Read
            Tool(
                name: "reminders_list_lists",
                description: "Get all reminder lists in the Reminders app. Returns list names, IDs, and reminder counts. Use this first to discover available lists before creating or searching reminders.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([:])
                ])
            ),
            Tool(
                name: "reminders_get_reminders",
                description: "Get reminders from the Reminders app. Can retrieve all reminders, reminders from a specific list, only incomplete reminders, or reminders due within a time range. Defaults to showing only incomplete reminders. Notes are not included — use reminders_get_reminder for full details.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "list_id": .object([
                            "type": .string("string"),
                            "description": .string("Filter to a specific list by ID (from reminders_list_lists)")
                        ]),
                        "list_name": .object([
                            "type": .string("string"),
                            "description": .string("Filter by list name (alternative to list_id)")
                        ]),
                        "include_completed": .object([
                            "type": .string("boolean"),
                            "description": .string("Include completed reminders. Defaults to false.")
                        ]),
                        "due_before": .object([
                            "type": .string("string"),
                            "description": .string("Return reminders due before this ISO 8601 datetime (e.g. '2026-03-15T23:59:59Z')")
                        ]),
                        "due_after": .object([
                            "type": .string("string"),
                            "description": .string("Return reminders due after this ISO 8601 datetime")
                        ]),
                        "limit": .object([
                            "type": .string("integer"),
                            "description": .string("Maximum reminders to return (default 50, max 200)")
                        ])
                    ])
                ])
            ),
            Tool(
                name: "reminders_get_reminder",
                description: "Get full details for a single reminder by ID, including notes, URL, and all fields. Use this when you need the complete information about a specific reminder. Notes may contain sensitive content.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "reminder_id": .object([
                            "type": .string("string"),
                            "description": .string("The ID of the reminder to retrieve")
                        ])
                    ]),
                    "required": .array([.string("reminder_id")])
                ])
            ),

            // P1: Write
            Tool(
                name: "reminders_create_reminder",
                description: "Create a new reminder. The title should be a short, scannable summary (under ~60 characters) — like a subject line, not a full sentence. Put full context, source details, and background into the notes field. If no list is specified, the reminder goes to the default Reminders list. Example: title='Reply to Sarah re: budget', notes='Sarah asked for Q3 budget feedback by Friday. See email from March 8.'",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "title": .object([
                            "type": .string("string"),
                            "description": .string("Short, scannable reminder title (aim for under 60 characters). Write it like a task subject line: 'Reply to Sarah re: budget' not 'Sarah Chen sent an email about the Q3 budget review asking for feedback by Friday'. Use the notes field for details.")
                        ]),
                        "list_id": .object([
                            "type": .string("string"),
                            "description": .string("ID of the list to add the reminder to")
                        ]),
                        "list_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the list (alternative to list_id)")
                        ]),
                        "due_date": .object([
                            "type": .string("string"),
                            "description": .string("When the reminder is due, ISO 8601 format (e.g. '2026-03-15T14:00:00Z')")
                        ]),
                        "remind_date": .object([
                            "type": .string("string"),
                            "description": .string("When to trigger the notification, ISO 8601 format. Defaults to due_date if not set.")
                        ]),
                        "priority": .object([
                            "type": .string("string"),
                            "description": .string("Priority: 'none', 'low', 'medium', or 'high'. Defaults to 'none'.")
                        ]),
                        "notes": .object([
                            "type": .string("string"),
                            "description": .string("Full context and details for the reminder. When creating from emails or messages, include the sender, date, key details, and any relevant quoted content here. Keep the title short and put the substance in notes.")
                        ]),
                        "flagged": .object([
                            "type": .string("boolean"),
                            "description": .string("Whether to flag this reminder")
                        ]),
                        "url": .object([
                            "type": .string("string"),
                            "description": .string("Optional URL to attach")
                        ])
                    ]),
                    "required": .array([.string("title")])
                ])
            ),
            Tool(
                name: "reminders_complete_reminder",
                description: "Mark a reminder as completed (done) or incomplete. Use this when the user says they finished a task or wants to check off a reminder. Do NOT use delete when the user means 'done'.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "reminder_id": .object([
                            "type": .string("string"),
                            "description": .string("The ID of the reminder to complete")
                        ]),
                        "completed": .object([
                            "type": .string("boolean"),
                            "description": .string("Set to true to complete, false to mark incomplete. Defaults to true.")
                        ])
                    ]),
                    "required": .array([.string("reminder_id")])
                ])
            ),
            Tool(
                name: "reminders_delete_reminder",
                description: "Permanently delete a single reminder. This cannot be undone. Use only when the user explicitly asks to delete or remove a reminder, NOT when they want to mark it complete.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "reminder_id": .object([
                            "type": .string("string"),
                            "description": .string("The ID of the reminder to delete")
                        ])
                    ]),
                    "required": .array([.string("reminder_id")])
                ])
            ),

            // P2: Write
            Tool(
                name: "reminders_update_reminder",
                description: "Edit properties of an existing reminder. Only provided fields are updated — omitted fields are untouched. For simply marking done, prefer reminders_complete_reminder.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "reminder_id": .object([
                            "type": .string("string"),
                            "description": .string("The ID of the reminder to update")
                        ]),
                        "title": .object([
                            "type": .string("string"),
                            "description": .string("New title (keep it short and scannable — under 60 characters)")
                        ]),
                        "notes": .object([
                            "type": .string("string"),
                            "description": .string("New notes (full context and details). Pass empty string to clear.")
                        ]),
                        "due_date": .object([
                            "type": .string("string"),
                            "description": .string("New due date (ISO 8601). Pass 'clear' to remove due date.")
                        ]),
                        "remind_date": .object([
                            "type": .string("string"),
                            "description": .string("New alert date (ISO 8601). Pass 'clear' to remove.")
                        ]),
                        "priority": .object([
                            "type": .string("string"),
                            "description": .string("New priority: 'none', 'low', 'medium', or 'high'")
                        ]),
                        "flagged": .object([
                            "type": .string("boolean"),
                            "description": .string("Whether the reminder is flagged")
                        ]),
                        "list_id": .object([
                            "type": .string("string"),
                            "description": .string("Move to this list by ID")
                        ]),
                        "list_name": .object([
                            "type": .string("string"),
                            "description": .string("Move to this list by name")
                        ]),
                        "url": .object([
                            "type": .string("string"),
                            "description": .string("New URL. Pass empty string to clear.")
                        ])
                    ]),
                    "required": .array([.string("reminder_id")])
                ])
            ),
            Tool(
                name: "reminders_create_list",
                description: "Create a new reminder list in the Reminders app.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the new list")
                        ])
                    ]),
                    "required": .array([.string("name")])
                ])
            ),
            Tool(
                name: "reminders_delete_list",
                description: "Delete a reminder list and ALL reminders in it. This is permanent and cannot be undone. Only use when the user has explicitly asked to delete the entire list.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "list_id": .object([
                            "type": .string("string"),
                            "description": .string("The ID of the list to delete")
                        ])
                    ]),
                    "required": .array([.string("list_id")])
                ])
            ),
            Tool(
                name: "reminders_search",
                description: "Search for reminders by keyword in title or notes. Use this when looking for a specific reminder by name or description.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "query": .object([
                            "type": .string("string"),
                            "description": .string("Search term to match against reminder titles and notes")
                        ]),
                        "list_id": .object([
                            "type": .string("string"),
                            "description": .string("Limit search to a specific list")
                        ]),
                        "include_completed": .object([
                            "type": .string("boolean"),
                            "description": .string("Include completed reminders. Defaults to false.")
                        ])
                    ]),
                    "required": .array([.string("query")])
                ])
            ),
        ]
    }
}
