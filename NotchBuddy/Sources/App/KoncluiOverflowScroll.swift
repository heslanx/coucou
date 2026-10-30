import SwiftUI

// Koncluí: an island card's content that can outgrow the island (a long question from Claude Code, with its options
// below it). While it fits it keeps its own layout, untouched; taller, it scrolls, and the edge with more beyond it
// fades out, so the cut reads as "more here" and never as a broken card. Kept outside `#if !APPSTORE` because the
// hook is in a view both builds compile.
struct KoncluiOverflowScroll<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var more = KoncluiOverflowEdges()

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView(.vertical) { content }
                .onScrollGeometryChange(for: KoncluiOverflowEdges.self) { g in
                    KoncluiOverflowEdges(above: g.contentOffset.y > 1,
                                         below: g.contentOffset.y + g.containerSize.height < g.contentSize.height - 1)
                } action: { _, edges in
                    more = edges
                }
                .mask(fade)
        }
    }

    private var fade: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(more.above ? 0 : 1), .black], startPoint: .top, endPoint: .bottom)
                .frame(height: 22)
            Color.black
            LinearGradient(colors: [.black, .black.opacity(more.below ? 0 : 1)], startPoint: .top, endPoint: .bottom)
                .frame(height: 22)
        }
    }
}

extension KoncluiOverflowScroll where Content == EmptyView {
    /// A question the island grows for. The island gives a card a fixed 98 pt slot; one taller than the default
    /// card fills the island instead (as Mail does), so it has the room the island made for it. A short one keeps
    /// the slot, unchanged.
    static func isTall(_ question: AskQuestion?) -> Bool {
        guard let question else { return false }
        return question.estimatedIslandHeight > IslandConst.viewLayouts[.question]!.height
    }
}

struct KoncluiOverflowEdges: Equatable {
    var above = false
    var below = false
}

extension View {
    /// Scrolls when taller than the room it is given; unchanged when it fits.
    func koncluiScrollsWhenTall() -> some View {
        KoncluiOverflowScroll { self }
    }
}
