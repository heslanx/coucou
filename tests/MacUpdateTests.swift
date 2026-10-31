import Foundation

@main
enum MacUpdateTests {
    static var failures = 0

    static func check(_ label: String, _ got: Bool) {
        if got { print("  ✓ \(label)") }
        else   { print("  ✗ \(label)"); failures += 1 }
    }

    static func release(_ tag: String, draft: Bool = false, pre: Bool = false, zip: Bool = true, body: String = "") -> [String: Any] {
        var assets: [[String: Any]] = [["name": "notes.txt", "browser_download_url": "https://github.com/x/notes.txt", "size": 3]]
        if zip {
            assets.append(["name": "Konclui.zip", "size": 34_000_000,
                           "browser_download_url": "https://updates.konclui.com/v1/mac/download/\(tag)/Konclui.zip"])
        }
        return ["tag_name": tag, "draft": draft, "prerelease": pre, "assets": assets, "body": body,
                "html_url": "https://updates.konclui.com/v1/mac/notes/\(tag)"]
    }

    static func json(_ list: [[String: Any]]) -> Data { try! JSONSerialization.data(withJSONObject: list) }

    static func main() {
        print("\nTags: only the Mac's")
        check("konclui-v0.5.1", MacUpdate.macVersion("konclui-v0.5.1") == "0.5.1")
        check("konclui-v1.0", MacUpdate.macVersion("konclui-v1.0") == "1.0")
        check("Coucou's v0.5.6 is not Koncluí's", MacUpdate.macVersion("v0.5.6") == nil)
        check("windows-v0.5.0 is not the Mac's", MacUpdate.macVersion("windows-v0.5.0") == nil)
        check("linux-latest", MacUpdate.macVersion("linux-latest") == nil)
        check("android-v0.2.0", MacUpdate.macVersion("android-v0.2.0") == nil)
        check("konclui-v0.5.1-beta", MacUpdate.macVersion("konclui-v0.5.1-beta") == nil)
        check("konclui-v", MacUpdate.macVersion("konclui-v") == nil)

        print("\nVersions compare as numbers")
        check("0.10.0 > 0.9.3", MacUpdate.isNewer("0.10.0", than: "0.9.3"))
        check("0.5.1 > 0.5", MacUpdate.isNewer("0.5.1", than: "0.5"))
        check("0.5 = 0.5.0", !MacUpdate.isNewer("0.5", than: "0.5.0") && !MacUpdate.isNewer("0.5.0", than: "0.5"))
        check("0.5.0 < 0.5.1", !MacUpdate.isNewer("0.5.0", than: "0.5.1"))
        check("1.0.0 > 0.99.99", MacUpdate.isNewer("1.0.0", than: "0.99.99"))

        print("\nThe newest published Mac release")
        do {
            let list = [
                release("windows-v0.6.0"), release("linux-latest"),
                release("konclui-v0.9.0", draft: true), release("konclui-v0.8.0", pre: true), release("konclui-v0.7.0", zip: false),
                release("konclui-v0.5.1"), release("konclui-v0.10.0", body: "Coucou 0.10.0\n\n## What's new\n\n- **One-click update** from the notch.\n- Other\n\n## Install\n- x"),
                release("konclui-v0.6.2"),
            ]
            let r = MacUpdate.latest(json(list))
            check("picks v0.10.0 over 0.6.2 and 0.5.1", r?.version == "0.10.0" && r?.tag == "konclui-v0.10.0")
            check("its Konclui.zip", r?.zipURL.lastPathComponent == "Konclui.zip" && r?.size == 34_000_000)
            check("its page", r?.pageURL.absoluteString == "https://updates.konclui.com/v1/mac/notes/konclui-v0.10.0")
            check("headline from the bold part", r?.headline == "One-click update")
            check("nothing for drafts and others only", MacUpdate.latest(json([release("konclui-v0.9.0", draft: true), release("windows-v1.0")])) == nil)
            check("garbage", MacUpdate.latest(Data("{\"message\":\"rate limited\"}".utf8)) == nil)
        }

        print("\nHeadline")
        check("plain bullet", MacUpdate.headline("## What's new\n\n- Faster pills") == "Faster pills")
        check("stops at the next section", MacUpdate.headline("## What's new\n\n## Install\n- download") == nil)
        check("no section", MacUpdate.headline("- something") == nil)
        check("long line cut", (MacUpdate.headline("## What's new\n- " + String(repeating: "a", count: 120)) ?? "").count == 69)

        print("\nOnly GitHub")
        check("github.com", MacUpdate.allowedHost("github.com"))
        check("objects.githubusercontent.com", MacUpdate.allowedHost("objects.githubusercontent.com"))
        check("release-assets.githubusercontent.com", MacUpdate.allowedHost("release-assets.githubusercontent.com"))
        check("not evilgithubusercontent.com", !MacUpdate.allowedHost("evilgithubusercontent.com"))
        check("not github.com.evil.io", !MacUpdate.allowedHost("github.com.evil.io"))
        check("nil", !MacUpdate.allowedHost(nil))
        check("updates.konclui.com", MacUpdate.allowedHost("updates.konclui.com"))
        check("not updates.konclui.com.evil.io", !MacUpdate.allowedHost("updates.konclui.com.evil.io"))

        print("\nWhere Coucou may replace itself")
        check("/Applications", MacUpdate.canReplace(bundlePath: "/Applications/Coucou.app", home: "/Users/l"))
        check("~/Applications", MacUpdate.canReplace(bundlePath: "/Users/l/Applications/Coucou.app", home: "/Users/l"))
        check("not DerivedData", !MacUpdate.canReplace(bundlePath: "/Users/l/Library/Developer/Xcode/DerivedData/x/Build/Products/Debug/Coucou.app", home: "/Users/l"))
        check("not Downloads", !MacUpdate.canReplace(bundlePath: "/Users/l/Downloads/Coucou.app", home: "/Users/l"))
        check("not a subfolder of Applications", !MacUpdate.canReplace(bundlePath: "/Applications/Tools/Coucou.app", home: "/Users/l"))

        print("\nWhen to look, when to say it")
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        check("never looked", MacUpdate.shouldCheck(last: nil, now: now))
        check("an hour ago: not yet", !MacUpdate.shouldCheck(last: now - 3600, now: now))
        check("seven hours ago", MacUpdate.shouldCheck(last: now - 7 * 3600, now: now))
        check("the clock went back", MacUpdate.shouldCheck(last: now + 3600, now: now))
        let r = MacUpdate.Release(version: "0.6.0", tag: "konclui-v0.6.0", zipURL: URL(string: "https://github.com/a")!, size: 1,
                                  pageURL: URL(string: "https://github.com/b")!, headline: nil)
        check("newer: announced", MacUpdate.shouldAnnounce(r, current: "0.5.1", snoozedVersion: nil, snoozedAt: nil, now: now))
        check("same: not", !MacUpdate.shouldAnnounce(r, current: "0.6.0", snoozedVersion: nil, snoozedAt: nil, now: now))
        check("older release (a dev build): not", !MacUpdate.shouldAnnounce(r, current: "0.7.0", snoozedVersion: nil, snoozedAt: nil, now: now))
        check("Later an hour ago: not", !MacUpdate.shouldAnnounce(r, current: "0.5.1", snoozedVersion: "0.6.0", snoozedAt: now - 3600, now: now))
        check("Later yesterday: again", MacUpdate.shouldAnnounce(r, current: "0.5.1", snoozedVersion: "0.6.0", snoozedAt: now - 25 * 3600, now: now))
        check("Later on an older version: this one shows", MacUpdate.shouldAnnounce(r, current: "0.5.1", snoozedVersion: "0.5.2", snoozedAt: now - 60, now: now))

        print("\nBlue Mochi while it waits")
        check("waiting: blue", MacUpdate.showsHint(r, current: "0.5.1", consent: true, laterVersion: nil, laterAt: nil, now: now))
        check("not asked yet: no", !MacUpdate.showsHint(r, current: "0.5.1", consent: nil, laterVersion: nil, laterAt: nil, now: now))
        check("said no: no", !MacUpdate.showsHint(r, current: "0.5.1", consent: false, laterVersion: nil, laterAt: nil, now: now))
        check("nothing found: no", !MacUpdate.showsHint(nil, current: "0.5.1", consent: true, laterVersion: nil, laterAt: nil, now: now))
        check("installed: no", !MacUpdate.showsHint(r, current: "0.6.0", consent: true, laterVersion: nil, laterAt: nil, now: now))
        check("Later an hour ago: no", !MacUpdate.showsHint(r, current: "0.5.1", consent: true, laterVersion: "0.6.0", laterAt: now - 3600, now: now))
        check("Later yesterday: blue again", MacUpdate.showsHint(r, current: "0.5.1", consent: true, laterVersion: "0.6.0", laterAt: now - 25 * 3600, now: now))
        check("Later on an older version: blue", MacUpdate.showsHint(r, current: "0.5.1", consent: true, laterVersion: "0.5.9", laterAt: now - 60, now: now))

        print("\nThe app in the zip")
        check("right id and version", MacUpdate.matches(infoPlist: ["CFBundleIdentifier": "com.konclui.mac", "CFBundleShortVersionString": "0.6.0"], version: "0.6.0"))
        check("another app", !MacUpdate.matches(infoPlist: ["CFBundleIdentifier": "com.evil.app", "CFBundleShortVersionString": "0.6.0"], version: "0.6.0"))
        check("another version", !MacUpdate.matches(infoPlist: ["CFBundleIdentifier": "com.konclui.mac", "CFBundleShortVersionString": "0.5.9"], version: "0.6.0"))
        check("requirement names Koncluí's team", MacUpdate.codeRequirement.contains("5M8RG3BCX2") && MacUpdate.codeRequirement.contains("anchor apple generic"))
        check("never Louis's team", !MacUpdate.codeRequirement.contains("256AUJ9555"))
        check("only Koncluí's update service", MacUpdate.releasesURL.absoluteString == "https://updates.konclui.com/v1/mac/releases")
        check("its notes page", MacUpdate.latestPageURL.absoluteString == "https://updates.konclui.com/v1/mac/notes/latest")

        if failures > 0 {
            print("\n\(failures) failure(s)")
            exit(1)
        }
        print("\nAll Mac update tests passed")
    }
}
