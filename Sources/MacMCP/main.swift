import MCP
import Foundation

let mode = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "mail"

switch mode {
case "reminders":
    let server = RemindersMCPServer()
    await server.run()
case "calendar":
    let server = CalendarMCPServer()
    await server.run()
default:
    let server = MailMCPServer()
    await server.run()
}
