#if !APPSTORE
import SwiftUI

// Koncluí: Orca's row of Settings → Agents. Orca runs Claude Code in its own terminals, so those sessions come through
// Claude Code's hooks; what this row decides is whether their permission requests and questions wait on the notch. It
// ships on (KoncluiOrcaCards, KoncluiPageRules.swift): the person runs many agents in Orca at once, and the notch is the one
// place that sees all of them. Other terminals keep their own switch, off by default, in Claude Code's popover.

struct KoncluiOrcaRow: View {
    @AppStorage(KoncluiOrcaCards.key) private var cardsOn = true
    @ObservedObject private var hooks = KoncluiHookStatus.shared
    @ObservedObject private var state = AppState.shared
    @State private var open = KoncluiAgentsDebug.opens("orca")

    var body: some View {
        KoncluiAgentRow(id: "orca", name: "Orca", colorHex: colorHex,
                        status: KoncluiAgentRows.status(.toggle, installed: cardsOn), isOpen: $open) {
            VStack(alignment: .leading, spacing: 10) {
                Text("konclui.orca.about")
                    .koncluiType(.detail)
                    .foregroundColor(KoncluiTheme.textBody)
                    .fixedSize(horizontal: false, vertical: true)
                Toggle(String(localized: "konclui.orca.toggle"), isOn: $cardsOn)
                if !hooks.snapshot.isInstalled(.claudeCode) && hooks.loaded {
                    Text("konclui.orca.needs-hooks")
                        .koncluiType(.detail)
                        .foregroundColor(KoncluiTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(6)
        }
    }

    private var colorHex: String {
        guard let def = PillCatalog.definition(for: ClaudeHost.orcaPillId) else { return KoncluiPalette.textSecondary }
        return PillColors.color(for: def.id, catalogColor: def.defaultColor, in: state.pillColors)
    }
}
#endif
