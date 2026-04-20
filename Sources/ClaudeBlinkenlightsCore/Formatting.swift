import Foundation

public func formatAge(_ age: TimeInterval) -> String {
    switch age {
    case ..<2:    return "now"
    case ..<60:   return "\(Int(age))s ago"
    case ..<3600: return "\(Int(age / 60))m ago"
    default:      return "\(Int(age / 3600))h ago"
    }
}
