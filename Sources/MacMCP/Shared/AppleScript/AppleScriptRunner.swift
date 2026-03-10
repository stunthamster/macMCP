import Foundation

actor AppleScriptRunner {
    private let timeoutSeconds: Double
    private let queue = DispatchQueue(label: "macmcp.applescript-runner")

    init(timeoutSeconds: Double = 30.0) {
        self.timeoutSeconds = timeoutSeconds
    }

    func run(script: String) async throws -> String {
        // Write script to temp file for reliable execution
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("macmcp_\(UUID().uuidString).scpt")
        try script.write(to: tempFile, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tempFile.path)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [tempFile.path]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: AppleScriptError.executionFailed(stderr: error.localizedDescription))
                    return
                }

                let timer = DispatchSource.makeTimerSource(queue: self.queue)
                timer.schedule(deadline: .now() + self.timeoutSeconds)
                timer.setEventHandler {
                    if process.isRunning {
                        process.terminate()
                        // Force kill after 2 second grace period
                        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                            if process.isRunning {
                                kill(process.processIdentifier, SIGKILL)
                            }
                        }
                    }
                }
                timer.resume()

                process.waitUntilExit()
                timer.cancel()

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                if process.terminationReason == .uncaughtSignal {
                    continuation.resume(throwing: AppleScriptError.timeout)
                    return
                }

                if process.terminationStatus != 0 {
                    if stderr.contains("-1743") || stderr.contains("not allowed") {
                        continuation.resume(throwing: AppleScriptError.permissionDenied)
                    } else if stderr.contains("Connection is invalid") || stderr.contains("Application isn't running") {
                        continuation.resume(throwing: AppleScriptError.mailNotRunning)
                    } else {
                        continuation.resume(throwing: AppleScriptError.executionFailed(stderr: stderr))
                    }
                    return
                }

                continuation.resume(returning: stdout)
            }
        }
    }

    func runJSON<T: Decodable>(_ type: T.Type, script: String) async throws -> T {
        let raw = try await run(script: script)
        let sanitized = Self.sanitizeJSON(raw)
        guard let data = sanitized.data(using: .utf8) else {
            throw AppleScriptError.invalidOutput(raw: raw)
        }
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(type, from: data)
        } catch {
            throw AppleScriptError.jsonDecodingFailed(raw: raw, underlying: error)
        }
    }

    /// Escape any unescaped control characters in a raw JSON string from AppleScript.
    ///
    /// AppleScript's `escapeForJSON` uses text item delimiters which operate on grapheme
    /// clusters, not Unicode scalar values. When a control character (LF, CR, tab, etc.)
    /// is fused into a grapheme cluster with an adjacent combining character (e.g. U+034F),
    /// the delimiter-based replacement misses it entirely and the raw control character
    /// passes through, breaking JSON parsing.
    ///
    /// This method scans the raw output at the Unicode scalar level and replaces any
    /// unescaped control characters (U+0000-U+001F, U+007F) with their JSON escape
    /// sequences. It also escapes U+2028/U+2029 which are valid Unicode but problematic
    /// in JSON consumed by JavaScript contexts.
    ///
    /// Per RFC 8259, raw control characters are never valid anywhere in a JSON document,
    /// so this is safe to apply to the entire string without tracking JSON parse state.
    static func sanitizeJSON(_ raw: String) -> String {
        var result = ""
        result.reserveCapacity(raw.count)

        var isEscaped = false
        for scalar in raw.unicodeScalars {
            if isEscaped {
                // Previous character was a backslash — this scalar is part of an
                // escape sequence, so pass it through unchanged.
                result.unicodeScalars.append(scalar)
                isEscaped = false
                continue
            }

            if scalar == "\\" {
                isEscaped = true
                result.unicodeScalars.append(scalar)
                continue
            }

            let value = scalar.value
            if value <= 0x1F || value == 0x7F {
                // Control character that should have been escaped — emit \uXXXX
                switch scalar {
                case "\n":
                    result += "\\n"
                case "\r":
                    result += "\\r"
                case "\t":
                    result += "\\t"
                default:
                    result += String(format: "\\u%04X", value)
                }
            } else if value == 0x2028 || value == 0x2029 {
                // Line/paragraph separators — valid Unicode but problematic in JSON
                result += String(format: "\\u%04X", value)
            } else {
                result.unicodeScalars.append(scalar)
            }
        }

        return result
    }
}
