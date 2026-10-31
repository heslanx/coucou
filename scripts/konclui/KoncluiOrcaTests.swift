import Foundation

// Koncluí K11: sessions in Orca terminals, and klaude's hooks.
// - routing: HookServer's own routing code (taken from the source by test-konclui-orca.sh) on payloads;
// - the focus command line, built from a terminal handle;
// - the Orca terminal registry;
// - ~/.klaude install and uninstall: HookServer's own installer code, on settings in a temp folder.
// No real settings file is read or written.

@main @MainActor
enum KoncluiOrcaTests {
    static var failures = 0
    static func check(_ name: String, _ ok: Bool) {
        print("  \(ok ? "✓" : "✗") \(name)")
        if !ok { failures += 1 }
    }

    // MARK: routing

    static func pill(_ payload: [String: Any]) -> String? { Router.route(name: "SessionStart", payload: payload)?.pill }

    static func routing() {
        print("Routing: which pill a session lands on")
        let orca: [String: Any] = ["term_program": "Orca", "bundle_id": "com.stablyai.orca", "session_id": "s"]
        check("TERM_PROGRAM Orca → agent_orca", pill(orca) == "agent_orca")
        check("TERM_PROGRAM Orca without a bundle id → agent_orca", pill(["term_program": "Orca"]) == "agent_orca")
        check("Orca's bundle id alone → agent_orca", pill(["bundle_id": "com.stablyai.orca"]) == "agent_orca")
        check("a tmux inside Orca (bundle id) → agent_orca", pill(["term_program": "tmux", "bundle_id": "com.stablyai.orca"]) == "agent_orca")
        check("Orca session is a workspace pill, not an external agent", Router.route(name: "Stop", payload: orca)?.external == false)
        check("Orca session records Orca as its host app", Router.route(name: "Stop", payload: orca)?.host == "com.stablyai.orca")
        for agent in ["codex", "gemini", "copilot", "muse", "hermes", "antigravity"] {
            var p = orca; p["coucou_agent"] = agent
            check("\(agent) in an Orca terminal → agent_orca", pill(p) == "agent_orca")
        }

        print("Routing: everything else keeps its route")
        check("VS Code → integration_claude",
              pill(["term_program": "vscode", "bundle_id": "com.microsoft.VSCode"]) == "integration_claude")
        check("VS Code has no terminal host", Router.route(name: "Stop", payload: ["term_program": "vscode"])?.host == nil)
        check("Cursor → agent_cursor",
              pill(["term_program": "vscode", "bundle_id": "com.todesktop.230313mzl4w4u92"]) == "agent_cursor")
        check("Warp → integration_claude",
              pill(["term_program": "WarpTerminal", "bundle_id": "dev.warp.Warp-Stable"]) == "integration_claude")
        check("Warp is the host", Router.route(name: "Stop", payload: ["term_program": "WarpTerminal"])?.host == "dev.warp.Warp-Stable")
        check("Terminal.app → integration_claude", pill(["term_program": "Apple_Terminal"]) == "integration_claude")
        check("iTerm → integration_claude", pill(["term_program": "iTerm.app"]) == "integration_claude")
        check("Ghostty → integration_claude", pill(["term_program": "ghostty"]) == "integration_claude")
        check("cmux (TERM_PROGRAM ghostty) → integration_claude",
              pill(["term_program": "ghostty", "bundle_id": "com.cmuxterm.app"]) == "integration_claude")
        check("Conductor (no TERM_PROGRAM) → integration_claude", pill(["bundle_id": "com.conductor.app"]) == "integration_claude")
        check("codex outside Orca → agent_codex", pill(["coucou_agent": "codex", "term_program": "Apple_Terminal"]) == "agent_codex")
        check("gemini outside Orca → agent_gemini", pill(["coucou_agent": "gemini", "term_program": "Apple_Terminal"]) == "agent_gemini")
        check("gemini outside Orca stays an external agent",
              Router.route(name: "Stop", payload: ["coucou_agent": "gemini"])?.external == true)
        check("unknown client is ignored", pill(["term_program": "xterm", "bundle_id": "com.example.app"]) == nil)
        check("no client at all is ignored", pill([:]) == nil)

        print("ClaudeHost: Orca in the host table")
        check("TERM_PROGRAM Orca → Orca", ClaudeHost.terminal(termProgram: "Orca", bundleId: "")?.name == "Orca")
        check("TERM_PROGRAM orca (any case) → Orca's bundle id", ClaudeHost.terminal(termProgram: "ORCA", bundleId: "")?.bundleId == "com.stablyai.orca")
        check("Orca by bundle id", ClaudeHost.terminal(termProgram: "", bundleId: "com.stablyai.orca")?.name == "Orca")
        check("isOrca: TERM_PROGRAM", ClaudeHost.isOrca(termProgram: "Orca", bundleId: ""))
        check("isOrca: bundle id", ClaudeHost.isOrca(termProgram: "", bundleId: "com.stablyai.orca"))
        check("isOrca: not VS Code", !ClaudeHost.isOrca(termProgram: "vscode", bundleId: "com.microsoft.VSCode"))
        check("isOrca: not Warp", !ClaudeHost.isOrca(termProgram: "WarpTerminal", bundleId: "dev.warp.Warp-Stable"))
        check("isOrca: not a plain terminal", !ClaudeHost.isOrca(termProgram: "", bundleId: ""))
        check("pill id", ClaudeHost.orcaPillId == "agent_orca")
    }

    // MARK: focus command

    static func focus() {
        print("Focus: orca terminal switch --terminal <handle>")
        let handle = "term_6c2544ab-5975-420d-841f-e942347a0344"
        check("arguments from a handle",
              ClaudeHost.orcaSwitchArguments(handle: handle) == ["terminal", "switch", "--terminal", handle])
        check("command line reads `orca terminal switch --terminal <handle>`",
              (["orca"] + (ClaudeHost.orcaSwitchArguments(handle: handle) ?? [])).joined(separator: " ")
                == "orca terminal switch --terminal \(handle)")
        check("no handle → no command", ClaudeHost.orcaSwitchArguments(handle: nil) == nil)
        check("empty handle → no command", ClaudeHost.orcaSwitchArguments(handle: "") == nil)
        check("an option is not a handle", ClaudeHost.orcaSwitchArguments(handle: "--json") == nil)
        check("a leading dash is not a handle", ClaudeHost.orcaSwitchArguments(handle: "-x") == nil)
        check("spaces are not a handle", ClaudeHost.orcaSwitchArguments(handle: "term_a b") == nil)
        check("shell characters are not a handle", ClaudeHost.orcaSwitchArguments(handle: "term_a;rm") == nil)
        check("a newline is not a handle", ClaudeHost.orcaSwitchArguments(handle: "term_a\nb") == nil)
        check("non-ASCII is not a handle", ClaudeHost.orcaSwitchArguments(handle: "term_é") == nil)
        check("a 128-byte handle passes", ClaudeHost.orcaSwitchArguments(handle: String(repeating: "a", count: 128)) != nil)
        check("a 129-byte handle does not", ClaudeHost.orcaSwitchArguments(handle: String(repeating: "a", count: 129)) == nil)
    }

    // MARK: registry

    static func registry() {
        print("OrcaTerminals: the terminal each session runs in")
        let r = OrcaTerminals()
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        r.note(session: "a", handle: "term_a", worktree: "wt-a", now: t0)
        r.note(session: "b", handle: "term_b", worktree: nil, now: t0)
        check("a session's terminal", r.terminal(session: "a") == OrcaTerminal(handle: "term_a", worktree: "wt-a"))
        check("a missing worktree is empty", r.terminal(session: "b")?.worktree == "")
        check("nothing to open before a session owns the pill", r.focusTerminal == nil)
        r.focus(session: "a")
        check("the pill opens its owner's terminal", r.focusTerminal?.handle == "term_a")
        r.focus(session: "b")
        check("ownership moves to the next session", r.focusTerminal?.handle == "term_b")
        r.note(session: "b", handle: nil, worktree: nil, now: t0)
        r.note(session: "b", handle: "", worktree: "x", now: t0)
        check("an event without a handle keeps what is known", r.terminal(session: "b")?.handle == "term_b")
        r.note(session: "b", handle: "term_b2", worktree: "wt-b", now: t0)
        check("a new handle replaces the old one", r.focusTerminal == OrcaTerminal(handle: "term_b2", worktree: "wt-b"))
        r.forget(session: "b")
        check("an ended session is forgotten", r.terminal(session: "b") == nil)
        check("and no longer opened", r.focusTerminal == nil)
        check("the other session is untouched", r.terminal(session: "a")?.handle == "term_a")

        print("OrcaTerminals: a card opens the terminal of the session it shows")
        let cards = OrcaTerminals()
        cards.note(session: "a", handle: "term_a", worktree: nil, now: t0)
        cards.note(session: "b", handle: "term_b", worktree: nil, now: t0)
        cards.focus(session: "a")
        check("a card nobody wrote opens nothing of its own", cards.terminal(task: "agent_orca") == nil)
        cards.shown(task: "agent_orca", session: "a")
        cards.shown(task: "agent_orca#b", session: "b")
        check("the pill's card opens the session it shows", cards.terminal(task: "agent_orca")?.handle == "term_a")
        check("a popped-out card opens its own session, not the pill's owner", cards.terminal(task: "agent_orca#b")?.handle == "term_b")
        cards.shown(task: "agent_orca", session: "b")
        check("the pill follows the session the board shows now", cards.terminal(task: "agent_orca")?.handle == "term_b")
        cards.forget(session: "b")
        check("a card whose session ended has no terminal to switch to", cards.terminal(task: "agent_orca#b") == nil)

        let aged = OrcaTerminals()
        aged.note(session: "old", handle: "term_old", worktree: nil, now: t0)
        aged.note(session: "new", handle: "term_new", worktree: nil, now: t0.addingTimeInterval(OrcaTerminals.maxSilence + 1))
        check("a session unheard of for 12 h is dropped", aged.terminal(session: "old") == nil && aged.terminal(session: "new") != nil)

        let capped = OrcaTerminals()
        for i in 0..<(OrcaTerminals.maxSessions + 10) {
            capped.note(session: "s\(i)", handle: "term_\(i)", worktree: nil, now: t0.addingTimeInterval(Double(i)))
        }
        check("the oldest are dropped past the cap",
              capped.terminal(session: "s0") == nil && capped.terminal(session: "s\(OrcaTerminals.maxSessions + 9)") != nil)
    }

    // MARK: klaude hooks

    static let foreignRtk: [String: Any] = ["matcher": "Bash", "hooks": [["type": "command", "command": "rtk hook claude"]]]
    static let foreignKonclui: [String: Any] = ["hooks": [["type": "command",
        "command": "/Users/me/Developments/konclui-project/klaude/hooks/guard.sh"]]]
    static let coucouEntry: [String: Any] = ["hooks": [["type": "command",
        "command": "\"/Users/me/Library/Application Support/NotchBuddy/nb-hook\"", "timeout": 10]]]
    static let events = ["SessionStart", "SessionEnd", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PostToolUseFailure",
                         "PermissionRequest", "Notification", "Stop", "StopFailure", "SubagentStart", "SubagentStop"]

    static func commands(_ settings: [String: Any], _ event: String) -> [String] {
        let groups = (settings["hooks"] as? [String: Any])?[event] as? [[String: Any]] ?? []
        return groups.flatMap { ($0["hooks"] as? [[String: Any]] ?? []).compactMap { $0["command"] as? String } }
    }

    static func load(_ url: URL) -> [String: Any] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    static func backups(_ dir: URL) -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("settings.json.bak-") }
    }

    static func klaude() throws {
        let fm = FileManager.default
        let home = fm.temporaryDirectory.appendingPathComponent("konclui-k11-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: home) }
        let klaudeDir = home.appendingPathComponent(".klaude")
        try fm.createDirectory(at: klaudeDir, withIntermediateDirectories: true)
        let url = KlaudeHooks.settingsURL(home: home)
        let server = HookServer.shared

        print("klaude: where it is")
        check("settings live in ~/.klaude", url.path == klaudeDir.appendingPathComponent("settings.json").path)
        check("klaude exists when ~/.klaude does", KlaudeHooks.exists(home: home))
        let bare = fm.temporaryDirectory.appendingPathComponent("konclui-k11-bare-\(UUID().uuidString)")
        try fm.createDirectory(at: bare, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: bare) }
        check("klaude is absent from an empty home", !KlaudeHooks.exists(home: bare))
        try fm.createDirectory(at: bare.appendingPathComponent(".local/bin"), withIntermediateDirectories: true)
        fm.createFile(atPath: bare.appendingPathComponent(".local/bin/klaude").path, contents: Data("#!/bin/sh\n".utf8))
        check("klaude exists when only its launcher does", KlaudeHooks.exists(home: bare))
        check("~/.claude is still where Claude Code's hooks go",
              HookServer.claudeSettingsURL.path.hasSuffix("/.claude/settings.json"))

        print("klaude: install keeps what is there and adds Koncluí's")
        var sample: [String: Any] = [
            "model": "claude-fable-5", "theme": "dark",
            "permissions": ["defaultMode": "default"],
            "env": ["KEEP": "me"],
            "hooks": ["PreToolUse": [foreignRtk, foreignKonclui], "Stop": [coucouEntry]],
        ]
        try JSONSerialization.data(withJSONObject: sample, options: [.prettyPrinted, .sortedKeys]).write(to: url)
        let before = try Data(contentsOf: url)
        check("not installed yet", !KlaudeHooks.installed(home: home))

        let previewText = try server.previewClaudeHooks(at: url, install: true)
        check("the preview is JSON for the whole file",
              (try? JSONSerialization.jsonObject(with: Data(previewText.utf8))) is [String: Any])
        check("a preview writes nothing", (try? Data(contentsOf: url)) == before && backups(klaudeDir).isEmpty)

        try server.writeClaudeHooks(at: url)
        var after = load(url)
        check("a dated backup of the original is taken",
              backups(klaudeDir).count == 1 && (try? Data(contentsOf: backups(klaudeDir)[0])) == before)
        check("installed", KlaudeHooks.installed(home: home))
        check("every event has Koncluí's nb-hook",
              events.allSatisfy { commands(after, $0).filter(KoncluiHook.owns).count >= 1 })
        check("the command is Koncluí's nb-hook, quoted",
              commands(after, "SessionStart").contains { $0.hasPrefix("\"") && $0.hasSuffix("Konclui/nb-hook\"") })
        check("PermissionRequest waits up to 120 s", {
            let g = ((after["hooks"] as? [String: Any])?["PermissionRequest"] as? [[String: Any]]) ?? []
            return g.contains { ($0["hooks"] as? [[String: Any]])?.contains { ($0["timeout"] as? Int) == 120 } == true }
        }())
        check("the AskUserQuestion hook is there", {
            let g = ((after["hooks"] as? [String: Any])?["PreToolUse"] as? [[String: Any]]) ?? []
            return g.contains { ($0["matcher"] as? String) == "AskUserQuestion"
                && (($0["hooks"] as? [[String: Any]])?.contains { ($0["command"] as? String)?.hasSuffix(" --ask") == true } == true) }
        }())
        check("the other tool's hook is kept", commands(after, "PreToolUse").contains("rtk hook claude"))
        check("a hook that only has konclui in its path is kept",
              commands(after, "PreToolUse").contains("/Users/me/Developments/konclui-project/klaude/hooks/guard.sh"))
        check("Coucou's hook is kept", commands(after, "Stop").contains { $0.contains("NotchBuddy/nb-hook") })
        check("settings outside hooks are untouched",
              (after["model"] as? String) == "claude-fable-5" && (after["theme"] as? String) == "dark"
              && (after["env"] as? [String: String]) == ["KEEP": "me"]
              && ((after["permissions"] as? [String: Any])?["defaultMode"] as? String) == "default")

        print("klaude: installing again does not pile up entries")
        _ = try server.previewClaudeHooks(at: url, install: true)
        try server.writeClaudeHooks(at: url)
        let again = load(url)
        check("one Koncluí entry per event, two on PreToolUse (events + AskUserQuestion)",
              events.allSatisfy { commands(again, $0).filter(KoncluiHook.owns).count == ($0 == "PreToolUse" ? 2 : 1) })
        check("the second backup does not replace the first", backups(klaudeDir).count == 2)
        check("foreign entries are still single",
              commands(again, "PreToolUse").filter { $0 == "rtk hook claude" }.count == 1)

        print("klaude: uninstall removes only Koncluí's")
        let installedBytes = try Data(contentsOf: url)
        let removalText = try server.previewClaudeHooks(at: url, install: false)
        check("the removal preview holds no Koncluí entry", !removalText.contains("Konclui/nb-hook"))
        check("a preview writes nothing", (try? Data(contentsOf: url)) == installedBytes)
        try server.writeClaudeHooks(at: url)
        after = load(url)
        check("not installed any more", !KlaudeHooks.installed(home: home))
        check("no Koncluí entry left", events.allSatisfy { commands(after, $0).filter(KoncluiHook.owns).isEmpty })
        check("the other tool's hook is kept", commands(after, "PreToolUse").contains("rtk hook claude"))
        check("the konclui-named foreign hook is kept",
              commands(after, "PreToolUse").contains("/Users/me/Developments/konclui-project/klaude/hooks/guard.sh"))
        check("Coucou's hook is kept", commands(after, "Stop").contains { $0.contains("NotchBuddy/nb-hook") })
        check("events that held only Koncluí's are gone", (after["hooks"] as? [String: Any])?["SessionStart"] == nil)
        let original: [AnyHashable: Any] = sample
        check("back to the settings it started with", NSDictionary(dictionary: after).isEqual(to: original))
        check("each write has its own backup", backups(klaudeDir).count == 3)

        print("klaude: edge cases")
        var noop = false
        do { _ = try server.previewClaudeHooks(at: url, install: false) }
        catch let e as NSError where e.domain == "CoucouNoop" { noop = true } catch {}
        check("nothing to remove is a no-op notice, not a rewrite", noop)

        _ = try server.previewClaudeHooks(at: url, install: true)
        try Data("{\"edited\": true}".utf8).write(to: url)
        var refused = false
        do { try server.writeClaudeHooks(at: url) } catch ClaudeSettingsFile.Failure.changed { refused = true } catch {}
        check("a file edited since the preview is not overwritten", refused && (load(url)["edited"] as? Bool) == true)

        try Data("{ not json".utf8).write(to: url)
        var invalid = false
        do { _ = try server.previewClaudeHooks(at: url, install: true) } catch ClaudeSettingsFile.Failure.invalid { invalid = true } catch {}
        check("invalid JSON is refused, never replaced", invalid && (try? String(contentsOf: url, encoding: .utf8)) == "{ not json")

        sample["hooks"] = "unexpected"
        try JSONSerialization.data(withJSONObject: sample).write(to: url)
        var unexpected = false
        do { _ = try server.previewClaudeHooks(at: url, install: true) } catch ClaudeSettingsFile.Failure.unexpectedHooks { unexpected = true } catch {}
        check("hooks of an unexpected type are refused", unexpected)

        try fm.removeItem(at: url)
        _ = try server.previewClaudeHooks(at: url, install: true)
        try server.writeClaudeHooks(at: url)
        let created = load(url)
        check("no settings.json yet: it is created with Koncluí's hooks only",
              events.allSatisfy { commands(created, $0).filter(KoncluiHook.owns).count >= 1 } && created.keys.sorted() == ["hooks"])
        let mode = (try? fm.attributesOfItem(atPath: url.path))?[.posixPermissions] as? NSNumber
        check("a new settings.json is private to the user", mode?.intValue == 0o600)
    }

    static func main() throws {
        routing()
        focus()
        registry()
        try klaude()
        if failures > 0 { print("\n\(failures) failure(s)"); exit(1) }
        print("\nKoncluí Orca and klaude: all checks passed")
    }
}
