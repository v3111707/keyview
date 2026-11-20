import Combine

/// Symbols of one key in the current layout.
struct KeyLabels: Equatable {
    var base = ""
    var shift = ""
    var caps = ""
    var capsShift = ""

    /// What the key types right now.
    func main(shift isShift: Bool, caps isCaps: Bool) -> String {
        switch (isShift, isCaps) {
        case (false, false): return base
        case (true, false): return shift
        case (false, true): return caps
        case (true, true): return capsShift
        }
    }

    /// Small Shift symbol for the key corner.
    var corner: String? { Self.cornerSymbol(base: base, shifted: shift) }

    /// The Shift symbol, unless it is only the capital of the same letter.
    static func cornerSymbol(base: String, shifted: String) -> String? {
        if shifted.isEmpty || shifted == base || shifted == base.uppercased() { return nil }
        return shifted
    }
}

/// Everything the keyboard view shows.
final class KeyboardState: ObservableObject {
    @Published var kind: KeyboardKind = .ansi
    @Published var labels: [UInt16: KeyLabels] = [:]
    @Published var pressed: Set<UInt16> = []
    @Published var shift = false
    @Published var capsLock = false
}
