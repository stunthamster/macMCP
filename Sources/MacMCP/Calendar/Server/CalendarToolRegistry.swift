import MCP

enum CalendarToolRegistry {
    static func allTools() -> [Tool] {
        [
            // P1: Read
            Tool(
                name: "calendar_list_calendars",
                description: "Get all calendars from the Calendar app. Returns calendar names, IDs, colors, types (local, iCloud, Exchange, etc.), and whether they are read-only. Use this first to discover available calendars before creating or searching events.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([:])
                ])
            ),
            Tool(
                name: "calendar_get_events",
                description: "Get events from the Calendar app within a date range. A date range is always required. If the user asks for 'my events' without specifying dates, default to today. For 'this week', use Monday–Sunday. For 'next week', use next Monday–Sunday. Returns event summaries without full notes — use calendar_get_event for complete details including notes and attendees.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "start_date": .object([
                            "type": .string("string"),
                            "description": .string("Start of date range, ISO 8601 format (e.g. '2026-03-09T00:00:00Z'). Required.")
                        ]),
                        "end_date": .object([
                            "type": .string("string"),
                            "description": .string("End of date range, ISO 8601 format (e.g. '2026-03-09T23:59:59Z'). Required. Maximum range is 90 days.")
                        ]),
                        "calendar_id": .object([
                            "type": .string("string"),
                            "description": .string("Filter to a specific calendar by ID (from calendar_list_calendars)")
                        ]),
                        "calendar_name": .object([
                            "type": .string("string"),
                            "description": .string("Filter by calendar name (alternative to calendar_id)")
                        ]),
                        "limit": .object([
                            "type": .string("integer"),
                            "description": .string("Maximum events to return (default 50, max 200)")
                        ])
                    ]),
                    "required": .array([.string("start_date"), .string("end_date")])
                ])
            ),
            Tool(
                name: "calendar_get_event",
                description: "Get full details for a single event by ID, including notes, location, URL, attendees, recurrence info, and alerts. Use this when you need complete information about a specific event. Notes may contain sensitive content.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "event_id": .object([
                            "type": .string("string"),
                            "description": .string("The ID of the event to retrieve")
                        ])
                    ]),
                    "required": .array([.string("event_id")])
                ])
            ),
            Tool(
                name: "calendar_search_events",
                description: "Search for events by keyword in title, notes, or location within a date range. A date range is required — for broad searches, use a wide range (e.g. past 30 days to next 30 days).",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "query": .object([
                            "type": .string("string"),
                            "description": .string("Search term to match against event titles, notes, and locations")
                        ]),
                        "start_date": .object([
                            "type": .string("string"),
                            "description": .string("Start of search range, ISO 8601 format. Required.")
                        ]),
                        "end_date": .object([
                            "type": .string("string"),
                            "description": .string("End of search range, ISO 8601 format. Required.")
                        ]),
                        "calendar_id": .object([
                            "type": .string("string"),
                            "description": .string("Limit search to a specific calendar")
                        ])
                    ]),
                    "required": .array([.string("query"), .string("start_date"), .string("end_date")])
                ])
            ),

            // P1: Write
            Tool(
                name: "calendar_create_event",
                description: "Create a new calendar event. The title should be clear and short (under 80 characters). For all-day events, set is_all_day to true and provide just the date for start_date (e.g. '2026-03-15'). For timed events, provide both start_date and end_date with times. If end_date is omitted for a timed event, defaults to 1 hour after start. Check for conflicts with calendar_get_events before creating events in busy time slots.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "title": .object([
                            "type": .string("string"),
                            "description": .string("Event title — keep it short and clear (under 80 characters)")
                        ]),
                        "start_date": .object([
                            "type": .string("string"),
                            "description": .string("Event start, ISO 8601 format (e.g. '2026-03-15T14:00:00Z' for timed, or '2026-03-15' for all-day)")
                        ]),
                        "end_date": .object([
                            "type": .string("string"),
                            "description": .string("Event end, ISO 8601 format. Defaults to 1 hour after start for timed events.")
                        ]),
                        "is_all_day": .object([
                            "type": .string("boolean"),
                            "description": .string("Whether this is an all-day event. Defaults to false.")
                        ]),
                        "calendar_id": .object([
                            "type": .string("string"),
                            "description": .string("ID of the calendar to add the event to")
                        ]),
                        "calendar_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the calendar (alternative to calendar_id)")
                        ]),
                        "location": .object([
                            "type": .string("string"),
                            "description": .string("Event location (address, room name, or virtual meeting link)")
                        ]),
                        "notes": .object([
                            "type": .string("string"),
                            "description": .string("Event notes/description. Put agenda items, context, and details here.")
                        ]),
                        "url": .object([
                            "type": .string("string"),
                            "description": .string("URL associated with the event (e.g. meeting link, document)")
                        ]),
                        "alert_minutes": .object([
                            "type": .string("integer"),
                            "description": .string("Minutes before event to trigger an alert. Common values: 0, 5, 10, 15, 30, 60, 1440 (1 day). Omit for no alert.")
                        ]),
                        "availability": .object([
                            "type": .string("string"),
                            "description": .string("Availability during this event: 'busy' (default), 'free', 'tentative', or 'unavailable'")
                        ]),
                    ]),
                    "required": .array([.string("title"), .string("start_date")])
                ])
            ),
            Tool(
                name: "calendar_update_event",
                description: "Update properties of an existing calendar event. Only provided fields are changed — omitted fields remain untouched. For recurring events, this modifies only the specific occurrence by default. Set update_span to 'future' for this and future occurrences.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "event_id": .object([
                            "type": .string("string"),
                            "description": .string("The ID of the event to update")
                        ]),
                        "title": .object([
                            "type": .string("string"),
                            "description": .string("New event title")
                        ]),
                        "start_date": .object([
                            "type": .string("string"),
                            "description": .string("New start date/time (ISO 8601)")
                        ]),
                        "end_date": .object([
                            "type": .string("string"),
                            "description": .string("New end date/time (ISO 8601)")
                        ]),
                        "is_all_day": .object([
                            "type": .string("boolean"),
                            "description": .string("Change to/from all-day event")
                        ]),
                        "location": .object([
                            "type": .string("string"),
                            "description": .string("New location. Pass empty string to clear.")
                        ]),
                        "notes": .object([
                            "type": .string("string"),
                            "description": .string("New notes. Pass empty string to clear.")
                        ]),
                        "url": .object([
                            "type": .string("string"),
                            "description": .string("New URL. Pass empty string to clear.")
                        ]),
                        "alert_minutes": .object([
                            "type": .string("integer"),
                            "description": .string("New alert in minutes before event. Pass -1 to remove all alerts.")
                        ]),
                        "calendar_id": .object([
                            "type": .string("string"),
                            "description": .string("Move event to this calendar by ID")
                        ]),
                        "calendar_name": .object([
                            "type": .string("string"),
                            "description": .string("Move event to this calendar by name")
                        ]),
                        "availability": .object([
                            "type": .string("string"),
                            "description": .string("New availability: 'busy', 'free', 'tentative', or 'unavailable'")
                        ]),
                        "update_span": .object([
                            "type": .string("string"),
                            "description": .string("For recurring events: 'this' (default, this occurrence only) or 'future' (this and future occurrences)")
                        ])
                    ]),
                    "required": .array([.string("event_id")])
                ])
            ),
            Tool(
                name: "calendar_delete_event",
                description: "Permanently delete a calendar event. This cannot be undone. For recurring events, specify delete_span to control whether to delete just this occurrence or this and future occurrences. Defaults to deleting only the specific occurrence.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "event_id": .object([
                            "type": .string("string"),
                            "description": .string("The ID of the event to delete")
                        ]),
                        "delete_span": .object([
                            "type": .string("string"),
                            "description": .string("For recurring events: 'this' (default, this occurrence only) or 'future' (this and future occurrences)")
                        ])
                    ]),
                    "required": .array([.string("event_id")])
                ])
            ),
        ]
    }
}
