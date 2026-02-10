import Foundation

enum ConsoleStream: String {
    case stdout
    case stderr
    case system
}

struct ConsoleLine: Identifiable, Hashable {
    let id = UUID()
    let timestamp: Date
    let text: String
    let stream: ConsoleStream
}
