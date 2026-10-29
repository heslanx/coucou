import Foundation

// Koncluí's WhatsApp block (App/KoncluiWhatsAppModel.swift): how a number reads, which stage the block is in for the
// state of the install and the link, and which sample messages the live notch preview shows for the options being
// edited. Pure: the rules run on the real WAInbox and WAFilters, no view, no network, no setting.

@main
enum KoncluiWhatsAppTests {

    static var failures = 0

    static func check(_ label: String, _ got: Bool) {
        if got { print("  ✓ \(label)") }
        else   { print("  ✗ \(label)"); failures += 1 }
    }

    static func same(_ label: String, _ got: String, _ want: String) {
        if got == want { print("  ✓ \(label)") }
        else           { print("  ✗ \(label): got \(got), want \(want)"); failures += 1 }
    }

    /// A Mac with GOWA installed and linked, switched on, with room for its pill: the everyday state.
    static var base = KoncluiWAInputs(enabled: true, hasRoom: true, gateway: .gowa, installed: true, addressSet: false,
                                      install: .idle, link: .connected)

    static func stage(_ edit: (inout KoncluiWAInputs) -> Void) -> KoncluiWAStage {
        var i = base
        edit(&i)
        return KoncluiWABlock.stage(i)
    }

    static let now = Date(timeIntervalSince1970: 1_800_000_000)

    static func samples(mute: Bool, focus: Bool = true, focusOn: Bool = false) -> [KoncluiWASample] {
        KoncluiWAPreview.samples(options: .init(muteGroups: mute, respectFocus: focus, focusOn: focusOn), now: now)
    }

    static func main() {
        print("Phone number")
        same("Brazil mobile, linked-device form", KoncluiPhone.format("5511912345678:12@s.whatsapp.net"), "+55 11 91234-5678")
        same("Brazil mobile, @c.us", KoncluiPhone.format("5511912345678@c.us"), "+55 11 91234-5678")
        same("Brazil landline", KoncluiPhone.format("551134567890@s.whatsapp.net"), "+55 11 3456-7890")
        same("a number typed with a plus", KoncluiPhone.format("+5511912345678"), "+55 11 91234-5678")
        same("United States", KoncluiPhone.format("14155550132@s.whatsapp.net"), "+1 415 555-0132")
        same("France", KoncluiPhone.format("33612345678@s.whatsapp.net"), "+33 6 12 34 56 78")
        same("Portugal", KoncluiPhone.format("351912345678@s.whatsapp.net"), "+351 912 345 678")
        same("Spain", KoncluiPhone.format("34612345678@s.whatsapp.net"), "+34 612 345 678")
        same("United Kingdom", KoncluiPhone.format("447911123456@s.whatsapp.net"), "+44 7911 123456")
        same("a country this does not know stays plain", KoncluiPhone.format("81312345678@s.whatsapp.net"), "+81312345678")
        same("a known country with a wrong length stays plain", KoncluiPhone.format("55119123@s.whatsapp.net"), "+55119123")
        same("a linked-device id is not a phone number", KoncluiPhone.format("1234567890123@lid"), WAJID.displayNumber("1234567890123@lid"))
        same("a group id stays plain", KoncluiPhone.format("120363000000000001@g.us"), WAJID.displayNumber("120363000000000001@g.us"))
        same("nothing", KoncluiPhone.format(""), "")

        print("\nDoors: what a number or a chat offers")
        let me = "5511912345678:12@s.whatsapp.net"
        check("a person's chat is a person", KoncluiWADoor.isPerson(me) && KoncluiWADoor.isPerson("5511912345678@c.us"))
        check("a group, a linked-device id and nonsense are not", !KoncluiWADoor.isPerson("120363000000000001@g.us")
              && !KoncluiWADoor.isPerson("1234567890123@lid") && !KoncluiWADoor.isPerson("12@s.whatsapp.net") && !KoncluiWADoor.isPerson("abc"))
        check("your number: open the chat first, then copy", KoncluiWADoor.actions(for: me, ignored: false) == [.openChat, .copyNumber])
        check("an ignored person adds Stop ignoring last", KoncluiWADoor.actions(for: me, ignored: true) == [.openChat, .copyNumber, .stopIgnoring])
        check("a group offers its id", KoncluiWADoor.actions(for: "120363000000000001@g.us", ignored: true) == [.copyChatId, .stopIgnoring])
        same("the chat opens on the digits only", KoncluiWADoor.chatURL(me)?.absoluteString ?? "", "whatsapp://send?phone=5511912345678")
        check("a group has no chat link", KoncluiWADoor.chatURL("120363000000000001@g.us") == nil)
        same("copy: the number with its plus", KoncluiWADoor.copyText(me), "+5511912345678")
        same("copy: a group's id as it is", KoncluiWADoor.copyText("120363000000000001@g.us"), "120363000000000001@g.us")

        print("\nValidation while typing")
        check("nothing typed", KoncluiWAIgnore.parse("   ") == .empty)
        check("a number with spaces and a plus", KoncluiWAIgnore.parse("+55 21 97777-1234") == .chat("5521977771234@s.whatsapp.net"))
        check("a chat id as it is", KoncluiWAIgnore.parse("120363000000000009@g.us") == .chat("120363000000000009@g.us"))
        check("too few digits", KoncluiWAIgnore.parse("12345") == .invalid)
        check("letters are not a number", KoncluiWAIgnore.parse("hello") == .invalid)
        check("an id needs both sides of the @", KoncluiWAIgnore.parse("@g.us") == .invalid && KoncluiWAIgnore.parse("abc@") == .invalid)
        check("port: empty keeps the default, a good port passes", !KoncluiWAAdvanced.portProblem("") && !KoncluiWAAdvanced.portProblem("47823")
              && !KoncluiWAAdvanced.portProblem("1024") && !KoncluiWAAdvanced.portProblem("65535"))
        check("port: too low, too high and not a number are flagged", KoncluiWAAdvanced.portProblem("80") && KoncluiWAAdvanced.portProblem("70000")
              && KoncluiWAAdvanced.portProblem("abc"))
        check("address: empty and http(s) pass", !KoncluiWAAdvanced.addressProblem("") && !KoncluiWAAdvanced.addressProblem("http://127.0.0.1:3000")
              && !KoncluiWAAdvanced.addressProblem("https://gateway.local"))
        check("address: no scheme, another scheme and no host are flagged", KoncluiWAAdvanced.addressProblem("127.0.0.1:3000")
              && KoncluiWAAdvanced.addressProblem("ftp://host") && KoncluiWAAdvanced.addressProblem("http://"))

        print("\nStage: what the block shows")
        check("connected: the calm line", stage { _ in } == .connected)
        check("not set up: the warning and Install WhatsApp", stage { $0.enabled = false; $0.installed = false; $0.link = .off } == .install)
        check("not set up, but switched on: still the install", stage { $0.installed = false; $0.link = .unreachable } == .install)
        check("install, step 1: looking for GOWA", stage { $0.installed = false; $0.install = .checking } == .installing(step: 0))
        check("install, step 2: downloading", stage { $0.installed = false; $0.install = .downloading(megabytes: 15) } == .installing(step: 1))
        check("install, step 3: checking the download", stage { $0.installed = false; $0.install = .verifying } == .installing(step: 2))
        check("install, step 4: installing and starting", stage { $0.installed = false; $0.install = .installing } == .installing(step: 3))
        check("an update from the popover shows its steps too", stage { $0.install = .downloading(megabytes: 15) } == .installing(step: 1))
        check("install failed: the reason and Try again", stage { $0.installed = false; $0.link = .off; $0.install = .failed("no build") } == .installFailed("no build"))
        check("an update that failed leaves the line (the popover says why)", stage { $0.install = .failed("no build") } == .connected)
        check("a finished install is no step", stage { $0.install = .done } == .connected)
        check("waiting for the QR scan", stage { $0.link = .needsQR } == .scanning)
        check("a gateway of the user's own that is linked needs no install", stage { $0.installed = false } == .connected)
        check("a gateway of the user's own waiting for the QR needs no install", stage { $0.installed = false; $0.link = .needsQR } == .scanning)
        check("a saved address needs no install", stage { $0.installed = false; $0.addressSet = true; $0.link = .unreachable } == .problem(.stopped))
        check("OpenWA has no install", stage { $0.gateway = .openwa; $0.installed = false; $0.link = .connecting } == .connecting)
        check("gateway answers, WhatsApp connecting", stage { $0.link = .connecting } == .connecting)
        check("enabled, controller not started yet", stage { $0.link = .off } == .connecting)
        check("problem: gateway stopped", stage { $0.link = .unreachable } == .problem(.stopped))
        check("problem: credentials refused", stage { $0.link = .unauthorized } == .problem(.unauthorized))
        check("problem: the gateway's own message", stage { $0.link = .failed("bad url") } == .problem(.other("bad url")))
        check("switched off", stage { $0.enabled = false; $0.link = .off } == .off)
        check("switched off wins over a stopped gateway", stage { $0.enabled = false; $0.link = .unreachable } == .off)
        check("no room for the pill", stage { $0.hasRoom = false; $0.link = .off } == .noRoom)
        check("no room wins over a link that is up", stage { $0.hasRoom = false } == .noRoom)
        check("an install in progress wins over everything", stage { $0.enabled = false; $0.hasRoom = false; $0.install = .verifying } == .installing(step: 2))

        print("\nStage: the shape and the dot")
        let setup: [KoncluiWAStage] = [.install, .installing(step: 2), .installFailed("x"), .scanning]
        let line: [KoncluiWAStage] = [.connected, .connecting, .off, .noRoom, .problem(.stopped), .problem(.unauthorized), .problem(.other("x"))]
        check("install, steps, failure and QR expand as a card", setup.allSatisfy(\.isSetup))
        check("connected, connecting, off, no room and problems stay a line", line.allSatisfy { !$0.isSetup })
        check("connected is green", KoncluiWAStage.connected.dot == .green)
        check("QR and steps are amber", KoncluiWAStage.scanning.dot == .amber && KoncluiWAStage.installing(step: 0).dot == .amber)
        check("problems and a failed install are red", KoncluiWAStage.problem(.stopped).dot == .red && KoncluiWAStage.installFailed("x").dot == .red)
        check("off and not set up are gray", KoncluiWAStage.off.dot == .gray && KoncluiWAStage.install.dot == .gray)
        check("the card lists four install steps", KoncluiWABlock.installSteps == 4 && KoncluiWAInstallPhase.installing.step == 3)

        print("\nPreview: mute groups on (the default)")
        do {
            let s = samples(mute: true)
            check("three conversations, newest first", s.map(\.kind) == [.direct, .mention, .group])
            check("the group without a mention is muted", s.first { $0.kind == .group }?.muted == true)
            check("the direct message and the mention are listed", s.filter { $0.kind != .group }.allSatisfy { !$0.muted })
            check("the header counts what the list holds (2 + 1)", KoncluiWAPreview.unread(s) == 3)
            check("nothing is quiet without a Focus", s.allSatisfy { !$0.quiet })
            check("the mention is a message that mentions you",
                  s.first { $0.kind == .mention }?.conversation.messages.last?.mentionsMe == true)
            check("the sample chats are a person and two groups",
                  s.map(\.conversation.isGroup) == [false, true, true])
            let names = s.map(\.conversation.name)
            check("names come from the copy", names == ["Marina Costa", "Design team", "Family"])
        }

        print("\nPreview: mute groups off")
        do {
            let s = samples(mute: false)
            check("the group is listed", s.allSatisfy { !$0.muted })
            check("the header counts all of it (2 + 1 + 3)", KoncluiWAPreview.unread(s) == 6)
        }

        print("\nPreview: a Focus")
        do {
            let s = samples(mute: true, focus: true, focusOn: true)
            check("what would have reached you arrives quietly", s.filter { $0.kind != .group }.allSatisfy(\.quiet))
            check("a muted group is not quiet, it is muted", s.first { $0.kind == .group }.map { $0.muted && !$0.quiet } == true)
            check("they stay listed", s.filter { $0.kind != .group }.allSatisfy { !$0.muted })
            let all = samples(mute: false, focus: true, focusOn: true)
            check("with groups on too, all three are quiet", all.allSatisfy(\.quiet))
            let ignored = samples(mute: true, focus: false, focusOn: true)
            check("a Focus is ignored when \"stay quiet\" is off", ignored.allSatisfy { !$0.quiet })
            check("quiet is Focus on and respected", KoncluiWAPreviewOptions(muteGroups: true, respectFocus: true, focusOn: true).quiet
                  && !KoncluiWAPreviewOptions(muteGroups: true, respectFocus: false, focusOn: true).quiet
                  && !KoncluiWAPreviewOptions(muteGroups: true, respectFocus: true, focusOn: false).quiet)
        }

        print("\nPreview: what it shows when not connected")
        let options = KoncluiWAPreviewOptions(muteGroups: true, respectFocus: true, focusOn: false)
        check("connected: the samples", { if case .samples = KoncluiWAPreview.content(link: .connected, options: options, now: now) { return true } else { return false } }())
        for link: KoncluiWALink in [.off, .connecting, .needsQR, .unreachable, .unauthorized, .failed("x")] {
            check("\(link): the real status line, no samples", KoncluiWAPreview.content(link: link, options: options, now: now) == .status(link))
        }

        print("\nPreview: the words and the dates")
        do {
            let copy = KoncluiWASampleCopy(directName: "A", directText: "a", mentionName: "B", mentionSender: "b", mentionText: "@x",
                                           groupName: "C", groupSender: "c", groupText: "z")
            let s = KoncluiWAPreview.samples(options: options, copy: copy, now: now)
            check("the copy flows into the conversations", s.map(\.conversation.name) == ["A", "B", "C"])
            check("sender names in groups", s.first { $0.kind == .mention }?.conversation.messages.last?.senderName == "b")
            check("every message is in the past", s.allSatisfy { $0.conversation.lastActivity < now })
            check("fixed ids, so nothing could reach a real chat",
                  Set(s.map(\.id)) == [KoncluiWAPreview.directChat, KoncluiWAPreview.mentionChat, KoncluiWAPreview.groupChat])
            check("the same input gives the same samples", s == KoncluiWAPreview.samples(options: options, copy: copy, now: now))
        }

        print(failures == 0 ? "\nPASS" : "\nFAIL: \(failures)")
        exit(failures == 0 ? 0 : 1)
    }
}
