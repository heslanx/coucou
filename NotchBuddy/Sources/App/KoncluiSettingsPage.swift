#if !APPSTORE
import SwiftUI

// Koncluí: a notch page of the hub (Geral, Abas ativas, Agentes, Chat, Integrações, Voz, Atalhos). Upstream's SettingsView
// has its own ScrollView, so the page's header cannot scroll away inside it as on the Flow pages; and a full 170 pt band
// pinned above it took a quarter of the window and cut the rows half way. Here the header is the compact band, pinned over
// the scroll view as a bar: the content scrolls under it and meets it through a soft edge, not a hard cut. This is the
// window's only glass (UX.md, "Visual system"): the one surface with real content moving behind it. Popovers keep the
// system's own. Reduce Transparency draws the band solid.
struct KoncluiSettingsPage: View {
    let page: HubPage
    let section: String
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        SettingsView(embeddedSection: section)
            .id(section)
            .koncluiPinnedHeader {
                HubHero(page: page, title: page.title, subtitle: HubPage.notchSubtitle(page), compact: true)
                    .environment(\.koncluiGlassHeader, !reduceTransparency)
                    .padding(.horizontal, KoncluiSpace.gutter)
                    .padding(.top, 24)
            }
            .koncluiUndoBar()   // the Atalhos reset and the weekly recap clear offer Undo (UX.md 1.5)
    }
}
#endif
