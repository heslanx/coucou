#if !APPSTORE
import SwiftUI

// Koncluí: everything clickable shows the pointing hand (docs/konclui/UX.md 1.4). Native buttons and links already do; a
// custom clickable view (a row, a chip, a sidebar item, an icon button) calls this once. A disabled one keeps the arrow.
extension View {
    func koncluiPointer(_ enabled: Bool = true) -> some View {
        pointerStyle(enabled ? .link : nil)
    }
}
#endif
