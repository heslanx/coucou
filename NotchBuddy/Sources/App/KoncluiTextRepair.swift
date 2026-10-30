import Foundation

// Koncluí: text macOS hands over already garbled. Some system processes carry a display name whose UTF-8 bytes were read
// as Mac Roman before it reaches us: in pt-BR the Virtualization service limactl starts is "Serviço de Máquina Virtual
// do app limactl", and LaunchServices (NSRunningApplication.localizedName, `lsappinfo`) gives "Servi√ßo de M√°quina…".
// Pure Foundation, so scripts/konclui/test-text-repair.sh runs it.
enum KoncluiTextRepair {
    /// The text as it was written when it is UTF-8 read as Mac Roman; any other text untouched. A real name almost never
    /// passes: it would have to be all Mac Roman and its bytes valid UTF-8, which takes a symbol such as "√" or "≈" right
    /// before an accented letter.
    static func unmangled(_ text: String) -> String {
        guard text.unicodeScalars.contains(where: { $0.value > 127 }),
              let bytes = text.data(using: .macOSRoman),
              let written = String(data: bytes, encoding: .utf8) else { return text }
        return written
    }
}
