import AppKit
import SwiftUI

// scripts/konclui/render-theme/render.sh: stills of the hub window's visual system, drawn offscreen with the real theme
// (KoncluiTheme.swift, KoncluiThemeCore.swift) around mock pages. It cannot show the real pages (they need the whole
// app); it shows what the theme does to the same content before and after: controls, the pinned header over a
// scroll view, the Notetaker's edges. Not in CI. Usage: render.sh [out dir]

// MARK: - Mock content

let hubBlue = Color(hex: "#3B9EFF")

/// A stand-in for HubHero: the band's shape, colour wash, title and subtitle. `compact` lowers the height only.
struct MockHero: View {
    let title: String
    let subtitle: String
    var compact = false
    var glass = false
    var color = Color(hex: "#8E939C")
    var inset: CGFloat = KoncluiSpace.cardPadding

    var body: some View {
        ZStack(alignment: .topLeading) {
            if glass { Rectangle().fill(.ultraThinMaterial) }
            Color(hex: "#020203").opacity(glass ? 0.72 : 1)
            RadialGradient(colors: [color.opacity(0.30), color.opacity(0.08), .clear], center: UnitPoint(x: 0.92, y: -0.1),
                           startRadius: 0, endRadius: 320)
            VStack(alignment: .leading, spacing: 8) {
                Text(title).koncluiType(.display)
                Text(subtitle).font(.system(size: 14)).foregroundColor(KoncluiTheme.textBody)
                    .frame(maxWidth: 420, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, inset).padding(.vertical, compact ? 20 : 26)
        }
        .frame(height: compact ? KoncluiSpace.compactBand : 170)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(color.opacity(0.16)))
    }
}

/// What SettingsView's General section is made of: GroupBoxes with toggles, a slider, buttons, a segmented control.
/// `themed` is the hub (styles injected and the rebrand rules applied); otherwise upstream's own styles.
struct MockGeneral: View {
    let themed: Bool
    @State private var sounds = true
    @State private var hover = false
    @State private var edge = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox("Demo") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Explore todos os recursos sem chave de API ou Claude Code. Nada é gravado no disco.")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                    primary("Experimentar modo demo")
                }.padding(6)
            }
            GroupBox("Som") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Ativar sons", isOn: $sounds)
                    HStack { Text("Volume"); Slider(value: .constant(0.6)); Text("60 %") }
                    HStack { secondary("Abrir a pasta de sons"); secondary("Recarregar sons") }
                }.padding(6)
            }
            GroupBox("Comportamento") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Abrir ao passar o cursor", isOn: .constant(false))
                    Toggle("Abrir com os alertas de todas as abas", isOn: .constant(false))
                    Toggle("Iniciar ao ligar o Mac", isOn: .constant(true))
                }.padding(6)
            }
            GroupBox("Tela") {
                VStack(alignment: .leading, spacing: 8) {
                    segmented
                    HStack(spacing: 8) { KoncluiStatus(tone: .ok, text: "Hooks instalados"); KoncluiStatus(tone: .attention, text: "Hooks não instalados", door: true) }
                }.padding(6)
            }
            GroupBox("Teclas") {
                HStack { KoncluiKeyCap(text: "⌥ ⌥"); KoncluiKeyCap(text: "⌃⌘V"); KoncluiKeyCap(text: "Esc") }.padding(6)
            }
        }
        .padding(.horizontal, KoncluiSpace.gutter)
        .padding(.top, 20).padding(.bottom, 28)
    }

    @ViewBuilder func primary(_ text: String) -> some View {
        if themed { Button(text) {}.buttonStyle(.koncluiPrimary) } else { Button(text) {}.buttonStyle(.borderedProminent) }
    }
    @ViewBuilder func secondary(_ text: String) -> some View {
        if themed { Button(text) {}.buttonStyle(.koncluiSecondary) } else { Button(text) {}.buttonStyle(.bordered) }
    }
    @ViewBuilder var segmented: some View {
        let picker = Picker("", selection: $edge) { Text("Embaixo").tag(0); Text("Automático").tag(1); Text("Em cima").tag(2) }
            .pickerStyle(.segmented).labelsHidden().fixedSize()
        if themed { picker.koncluiSegmented() } else { picker }
    }
}

// MARK: - Pages

/// Geral: before = the full 170 pt band pinned above a scroll view (hard cut); after = the compact bar pinned over it.
struct GeneralPage: View {
    let after: Bool
    @State private var position: ScrollPosition

    init(after: Bool, scrolled: CGFloat) {
        self.after = after
        _position = State(initialValue: ScrollPosition(y: scrolled))
    }

    var body: some View {
        let scroll = ScrollView {
            MockGeneral(themed: after)
                .frame(maxWidth: 1100, alignment: .leading)
        }
        .scrollPosition($position)
        Group {
            if after {
                scroll
                    .koncluiPinnedHeader {
                        MockHero(title: "Geral", subtitle: "A Koru, seus sons e o comportamento do notch.", compact: true, glass: true)
                            .padding(.horizontal, KoncluiSpace.gutter).padding(.top, 24)
                    }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    MockHero(title: "Geral", subtitle: "A Koru, seus sons e o comportamento do notch.", inset: 26)
                        .padding(.horizontal, 28).padding(.top, 24)
                    scroll
                }
            }
        }
        .environment(\.koncluiHub, after)
        .groupBoxStyle(KoncluiOptionalGroupBox(on: after))
        .toggleStyle(KoncluiOptionalToggle(on: after))
        .tint(KoncluiTheme.accent)
        .frame(width: 860, height: 700)
        .background(KoncluiTheme.panel)
        .preferredColorScheme(.dark)
    }
}

/// The hub's styles when `on`, the system's otherwise (a ViewModifier cannot switch a style, so these wrap the choice).
struct KoncluiOptionalGroupBox: GroupBoxStyle {
    let on: Bool
    @ViewBuilder func makeBody(configuration: Configuration) -> some View {
        if on { KoncluiGroupBoxStyle().makeBody(configuration: configuration) } else { GroupBox(configuration) }
    }
}
struct KoncluiOptionalToggle: ToggleStyle {
    let on: Bool
    @ViewBuilder func makeBody(configuration: Configuration) -> some View {
        if on { KoncluiToggleStyle().makeBody(configuration: configuration) } else { Toggle(configuration).toggleStyle(.checkbox) }
    }
}

/// Notetaker: the header card, the list column and the detail pane, with guides at the page's two edges.
struct NotetakerPage: View {
    let after: Bool
    private var listLeading: CGFloat { after ? KoncluiSpace.gutter : 14 }
    private var detailInset: CGFloat { after ? KoncluiSpace.gutter : 32 }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                MockHero(title: "Notetaker", subtitle: "Suas chamadas transcritas pessoa por pessoa, com um resumo e as tarefas. Sem bot na reunião.",
                         compact: true, color: hubBlue, inset: after ? KoncluiSpace.cardPadding : 20)
                    .padding(.horizontal, KoncluiSpace.gutter).padding(.top, 24)
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 10) {
                        Button { } label: {
                            HStack(spacing: 8) { Circle().fill(.foreground).frame(width: 10, height: 10); Text("Gravar uma chamada") }
                                .frame(maxWidth: .infinity)
                        }.buttonStyle(KoncluiHubButtonStyle(kind: .primary)).padding(.top, 16)
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lock").font(.system(size: 11))
                            Text("Tudo fica no seu Mac. Avise as pessoas da chamada que você está gravando.").font(.system(size: 11))
                        }.foregroundColor(KoncluiTheme.textSecondary).padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(KoncluiTheme.card))
                        Spacer()
                    }
                    .padding(.leading, listLeading).padding(.trailing, KoncluiSpace.notesColumnInner).padding(.bottom, 14)
                    .frame(width: KoncluiSpace.notesColumn)
                    .overlay(alignment: .trailing) { Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1) }
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Reunião de produto").font(.system(size: 24, weight: .bold))
                        Text("quarta-feira, 29 de outubro · 10:02 → 10:41").font(.system(size: 13)).foregroundColor(KoncluiTheme.textSecondary)
                        RoundedRectangle(cornerRadius: 14).fill(KoncluiTheme.card).frame(height: 120)
                            .overlay(Text("Resumo da chamada").foregroundColor(KoncluiTheme.textBody))
                    }
                    .padding(.horizontal, detailInset).padding(.top, 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            // Guides: the page's left and right edge (the header card's edges), in magenta.
            HStack(spacing: 0) {
                Rectangle().fill(Color.pink.opacity(0.9)).frame(width: 1).padding(.leading, KoncluiSpace.gutter)
                Spacer()
                Rectangle().fill(Color.pink.opacity(0.9)).frame(width: 1).padding(.trailing, KoncluiSpace.gutter)
            }
        }
        .frame(width: 860, height: 420)
        .background(KoncluiTheme.panel)
        .preferredColorScheme(.dark)
    }
}

/// Abas ativas: list-selection checkboxes (labels hidden) and the status of each row.
struct ActiveTabsPage: View {
    let after: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ABAS ATIVAS").koncluiType(.label).foregroundColor(KoncluiTheme.textTertiary)
            VStack(spacing: 0) {
                row("Claude Code", on: true, status: after ? AnyView(KoncluiStatus(tone: .ok, text: "Hooks instalados", door: true))
                                                    : AnyView(Text("Hooks instalados").font(.system(size: 12)).foregroundColor(.secondary)))
                Divider()
                row("Codex", on: true, status: after ? AnyView(KoncluiStatus(tone: .attention, text: "Hooks não instalados", door: true))
                                                   : AnyView(Text("Hooks não instalados").font(.system(size: 12)).foregroundColor(.secondary)))
                Divider()
                row("Cursor", on: false, status: nil)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(KoncluiTheme.card))
        }
        .padding(KoncluiSpace.gutter)
        .frame(width: 560, height: 230, alignment: .topLeading)
        .background(KoncluiTheme.panel)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder func row(_ name: String, on: Bool, status: AnyView?) -> some View {
        HStack {
            Text(name).font(.system(size: 13.5, weight: .medium))
            Spacer()
            if let status { status }
            check(on)
        }.padding(.vertical, 8)
    }
    @ViewBuilder func check(_ on: Bool) -> some View {
        if after { Toggle("", isOn: .constant(on)).labelsHidden().toggleStyle(KoncluiToggleStyle()) }
        else { Toggle("", isOn: .constant(on)).labelsHidden().toggleStyle(.checkbox) }
    }
}

/// Ditado: before = two primaries (the band's "Gravar uma chamada" and the setup card's "Ativar o ditado"); after = one.
struct DictationPage: View {
    let after: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ZStack(alignment: .bottomLeading) {
                MockHero(title: "Olá, Erick", subtitle: after ? "Segure ⌥ em qualquer app, fale e solte: suas palavras são coladas onde você digita."
                                                              : "Segure ⌥ da direita em qualquer lugar, fale e solte: está colado.", color: Color(hex: "#FB923C"))
                Button(after ? "Ativar o ditado" : "Gravar uma chamada") {}
                    .buttonStyle(KoncluiHubButtonStyle(kind: .primary))
                    .padding(.leading, KoncluiSpace.cardPadding).padding(.bottom, 20)
            }
            if !after {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "mic.badge.plus").font(.system(size: 20)).foregroundColor(KoncluiTheme.accent)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dite em qualquer lugar do seu Mac").koncluiType(.title)
                        Text("Segure ⌥ da direita em qualquer app, fale e solte: suas palavras são coladas onde você digita.")
                            .font(.system(size: 13)).foregroundColor(KoncluiTheme.textBody)
                        Button("Ativar o ditado") {}.buttonStyle(KoncluiHubButtonStyle(kind: .primary))
                    }
                    Spacer()
                }.padding(18).background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "#150f0a")))
            }
            Text("HISTÓRICO").koncluiType(.label).foregroundColor(KoncluiTheme.textTertiary)
            RoundedRectangle(cornerRadius: 14).fill(KoncluiTheme.card).frame(height: after ? 160 : 80)
                .overlay(Text(after ? "Seus ditados aparecerão aqui." : "Seus ditados aparecerão aqui. Segure ⌥ da direita em qualquer app e fale.")
                    .font(.system(size: 13.5)).foregroundColor(KoncluiTheme.textSecondary))
        }
        .padding(.horizontal, KoncluiSpace.gutter).padding(.top, 24)
        .frame(width: 860, height: 520, alignment: .topLeading)
        .background(KoncluiTheme.panel)
        .preferredColorScheme(.dark)
    }
}

/// Buttons: enabled and disabled primaries, before (full orange either way) and after.
struct ButtonsStill: View {
    let after: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Button("Adicionar") {}.buttonStyle(KoncluiHubButtonStyle(kind: .primary))
                Button("Adicionar") {}.buttonStyle(KoncluiHubButtonStyle(kind: .primary)).disabled(true)
                Button("Abrir ajustes") {}.buttonStyle(KoncluiHubButtonStyle(kind: .secondary))
                Button("Abrir ajustes") {}.buttonStyle(KoncluiHubButtonStyle(kind: .secondary)).disabled(true)
                Button("Apagar", role: .destructive) {}.buttonStyle(KoncluiHubButtonStyle(kind: .secondary))
            }
            KoncluiField(label: "Você diz", placeholder: "minha assinatura", text: .constant(""), hint: "Escreva primeiro o que você diz.")
                .frame(width: 380)
            HStack(spacing: 14) {
                KoncluiStatus(tone: .ok, text: "Instalado")
                KoncluiStatus(tone: .attention, text: "Hooks não instalados", door: true)
                KoncluiStatus(tone: .error, text: "Sem conexão")
                KoncluiStatus(tone: .off, text: "Desligado")
            }
        }
        .padding(KoncluiSpace.gutter)
        .frame(width: 860, height: 230, alignment: .topLeading)
        .background(KoncluiTheme.panel)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Render

/// The macOS 26 scroll edge effect is composited by the window server: an offscreen `cacheDisplay` draws that scroll
/// view blank. This shows the view in a real window (non-activating, at the screen's bottom right) for a moment and
/// captures it from the window server; a window of this process needs no screen recording permission.
typealias WindowImageFunction = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?
@MainActor func renderLive<V: View>(_ view: V, size: CGSize, to url: URL, settle: TimeInterval = 1.0) {
    let host = NSHostingView(rootView: view)
    host.frame = CGRect(origin: .zero, size: size)
    let screen = NSScreen.main?.frame ?? .zero
    let panel = NSPanel(contentRect: CGRect(x: screen.maxX - size.width - 20, y: screen.minY + 20, width: size.width, height: size.height),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.appearance = NSAppearance(named: .darkAqua)
    panel.contentView = host
    panel.level = .floating
    panel.ignoresMouseEvents = true
    panel.hasShadow = false
    panel.orderFrontRegardless()
    RunLoop.current.run(until: Date().addingTimeInterval(settle))
    // CGWindowListCreateImage is not in the SDK any more; the symbol is still there.
    if let symbol = dlsym(dlopen(nil, RTLD_NOW), "CGWindowListCreateImage") {
        let capture = unsafeBitCast(symbol, to: WindowImageFunction.self)
        // kCGWindowListOptionIncludingWindow; kCGWindowImageBoundsIgnoreFraming | kCGWindowImageBestResolution
        if let image = capture(.null, 1 << 3, UInt32(panel.windowNumber), (1 << 0) | (1 << 3))?.takeRetainedValue() {
            try? NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?.write(to: url)
            print("wrote", url.path)
        }
    }
    panel.orderOut(nil)
}

@MainActor func render<V: View>(_ view: V, size: CGSize, to url: URL, settle: TimeInterval = 0.6) {
    let host = NSHostingView(rootView: view)
    host.frame = CGRect(origin: .zero, size: size)
    let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: .darkAqua)
    window.contentView = host
    window.backgroundColor = .black
    window.orderBack(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(settle))
    host.layoutSubtreeIfNeeded()
    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
    host.cacheDisplay(in: host.bounds, to: rep)
    try? rep.representation(using: .png, properties: [:])?.write(to: url)
    window.orderOut(nil)
    print("wrote", url.path)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)
    let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
    try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    for after in [false, true] {
        let tag = after ? "after" : "before"
        for (name, offset) in [("top", CGFloat(0)), ("scrolled", CGFloat(190))] {
            let url = out.appendingPathComponent("geral-\(tag)-\(name).png"), size = CGSize(width: 860, height: 700)
            if after { renderLive(GeneralPage(after: true, scrolled: offset), size: size, to: url) }
            else { render(GeneralPage(after: false, scrolled: offset), size: size, to: url) }
        }
        render(NotetakerPage(after: after), size: CGSize(width: 860, height: 420), to: out.appendingPathComponent("notetaker-\(tag).png"))
        render(ActiveTabsPage(after: after), size: CGSize(width: 560, height: 230), to: out.appendingPathComponent("abas-ativas-\(tag).png"))
        render(DictationPage(after: after), size: CGSize(width: 860, height: 520), to: out.appendingPathComponent("ditado-\(tag).png"))
    }
    render(ButtonsStill(after: true), size: CGSize(width: 860, height: 230), to: out.appendingPathComponent("components.png"))
}
