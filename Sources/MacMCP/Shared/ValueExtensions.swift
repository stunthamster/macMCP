import MCP

extension Value {
    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    var intValue: Int? {
        switch self {
        case .int(let i): return i
        case .double(let d):
            guard d.isFinite, d == d.rounded(.towardZero), d >= Double(Int.min), d <= Double(Int.max) else {
                return nil
            }
            return Int(d)
        case .string(let s): return Int(s)
        default: return nil
        }
    }

    var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }
}
