# macMCP

A [Model Context Protocol](https://modelcontextprotocol.io) (MCP) server that gives AI assistants native access to macOS Mail, Reminders, and Calendar. Built in Swift, it bridges Claude and other MCP-compatible clients to Apple's native apps and frameworks.

## Features

### Mail (via AppleScript)
- List accounts and mailboxes
- Read and search emails with pagination
- Get unread counts (per account, mailbox, or global)
- Set colored flags on messages
- Permission diagnostics with guided setup

### Reminders (via EventKit)
- Full CRUD for reminders and lists
- Priority, due dates, flags, notes, and URLs
- Search by keyword across all lists
- Filter by completion status and date range

### Calendar (via EventKit)
- Full CRUD for calendar events
- All-day and timed events with alerts
- Recurring event support (update/delete this or future occurrences)
- Search events across date ranges (up to 90 days)
- Calendar type detection (local, iCloud, Exchange, subscription)

## Requirements

- macOS 14 (Sonoma) or later
- Swift 6.0+
- Permissions granted for Mail, Reminders, and/or Calendar when prompted

## Building

```bash
swift build
```

For an optimized build:

```bash
swift build -c release
```

The built binary is at `.build/release/MacMCP`.

## Usage

macMCP runs as an MCP server over stdio. It operates in one of three modes:

```bash
# Mail mode (default)
MacMCP

# Reminders mode
MacMCP reminders

# Calendar mode
MacMCP calendar
```

### Claude Desktop Configuration

Add entries to your Claude Desktop MCP config (`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "mac-mail": {
      "command": "/path/to/MacMCP"
    },
    "mac-reminders": {
      "command": "/path/to/MacMCP",
      "args": ["reminders"]
    },
    "mac-calendar": {
      "command": "/path/to/MacMCP",
      "args": ["calendar"]
    }
  }
}
```

### Claude Code Configuration

Add to your Claude Code MCP settings (`~/.claude/settings.json`):

```json
{
  "mcpServers": {
    "mac-mail": {
      "command": "/path/to/MacMCP"
    },
    "mac-reminders": {
      "command": "/path/to/MacMCP",
      "args": ["reminders"]
    },
    "mac-calendar": {
      "command": "/path/to/MacMCP",
      "args": ["calendar"]
    }
  }
}
```

## Available Tools

### Mail Tools (8)

| Tool | Description |
|------|-------------|
| `check_permissions` | Diagnose Mail.app access and get setup instructions |
| `mail_list_accounts` | List configured email accounts |
| `mail_list_mailboxes` | List mailboxes/folders for an account |
| `mail_list_messages` | List messages with pagination (default 25, max 100) |
| `mail_read_message` | Read full email content |
| `mail_search_messages` | Search by subject, sender, or read status |
| `mail_set_flag` | Set flag color (Red/Orange/Yellow/Green/Blue/Purple/Gray) or clear |
| `mail_get_unread_count` | Get unread message counts |

### Reminders Tools (10)

| Tool | Description |
|------|-------------|
| `reminders_list_lists` | List all reminder lists |
| `reminders_get_reminders` | Get reminders with filters (list, status, date range) |
| `reminders_get_reminder` | Get a single reminder's details |
| `reminders_create_reminder` | Create a reminder with optional due date, priority, notes, URL |
| `reminders_update_reminder` | Update an existing reminder |
| `reminders_complete_reminder` | Mark a reminder as complete |
| `reminders_delete_reminder` | Delete a reminder |
| `reminders_create_list` | Create a new reminder list |
| `reminders_delete_list` | Delete a reminder list |
| `reminders_search` | Search reminders by keyword |

### Calendar Tools (7)

| Tool | Description |
|------|-------------|
| `calendar_list_calendars` | List all calendars with type and source info |
| `calendar_get_events` | Get events in a date range |
| `calendar_get_event` | Get full event details |
| `calendar_search_events` | Search events by keyword (up to 90-day range) |
| `calendar_create_event` | Create an event with title, time, location, alerts, recurrence |
| `calendar_update_event` | Update an event (this or future occurrences) |
| `calendar_delete_event` | Delete an event (this or future occurrences) |

## Architecture

```
Sources/MacMCP/
├── main.swift                 # Entry point and mode selection
├── Mail/
│   ├── AppleScript/           # AppleScript generators for Mail.app
│   ├── Models/                # Mail data types
│   └── Server/                # MCP server and tool definitions
├── Reminders/
│   ├── EventKit/              # EventKit integration
│   ├── Models/                # Reminder data types
│   ├── Security/              # Input validation, rate limiting
│   └── Server/                # MCP server and tool definitions
├── Calendar/
│   ├── EventKit/              # EventKit integration
│   ├── Models/                # Calendar data types
│   ├── Security/              # Input validation
│   └── Server/                # MCP server and tool definitions
└── Shared/
    ├── AppleScript/           # AppleScript executor and helpers
    └── Server/                # Common input validation
```

## Safety and Security

- **Input validation** — All user inputs are validated for control characters and length limits to prevent AppleScript injection
- **Rate limiting** — Write operations (create/delete) are rate-limited per session (50 creates/min, 10 deletes/min, 100 lifetime deletes)
- **Output sanitization** — HTML stripping, zero-width character removal, and untrusted content warnings
- **Permission handling** — Graceful EventKit access requests with clear diagnostic messages
- **Read-only detection** — Shared lists and subscription calendars are identified and protected

## Dependencies

- [swift-sdk](https://github.com/modelcontextprotocol/swift-sdk) (0.11.x) — Model Context Protocol Swift SDK
- EventKit framework — Native calendar and reminders access

## License

GPL-3.0 — see [LICENSE](LICENSE) for details.
