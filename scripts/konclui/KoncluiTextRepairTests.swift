import Foundation

// scripts/konclui/test-text-repair.sh: a name macOS garbled (UTF-8 read as Mac Roman) comes back as written; every
// other name is left alone.
@main
struct KoncluiTextRepairTests {
    static func main() {
        var failures = 0
        func check(_ text: String, _ expected: String) {
            let got = KoncluiTextRepair.unmangled(text)
            if got != expected { failures += 1; print("FAIL \"\(text)\" -> \"\(got)\", expected \"\(expected)\"") }
        }

        // As LaunchServices gives the Virtualization service limactl starts, on a Mac in pt-BR.
        check("Servi\u{221A}\u{00DF}o de M\u{221A}\u{00B0}quina Virtual do app limactl", "Serviço de Máquina Virtual do app limactl")
        // Any UTF-8 text read as Mac Roman comes back.
        for written in ["Ação", "Café", "Größe", "日本語", "Zoë — Notas", "naïve"] {
            if let bytes = written.data(using: .utf8), let garbled = String(data: bytes, encoding: .macOSRoman) {
                check(garbled, written)
            } else { failures += 1; print("FAIL could not garble \"\(written)\"") }
        }
        // Names already right stay as they are.
        for name in ["Google Chrome", "Serviço de Máquina Virtual", "Café", "Ação", "Größe", "日本語", "Zoë — Notas",
                     "Música", "São Paulo", "WindowServer", "", "kernel_task"] {
            check(name, name)
        }

        if failures == 0 { print("KoncluiTextRepair: all checks passed.") } else { print("\(failures) failed"); exit(1) }
    }
}
