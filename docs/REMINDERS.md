# Coucou reminders

Coucou can show scheduled reminders as a floating card or a full-screen alert. Reminders are stored locally on the Mac. The app does not read calendar events, sync reminders to iCloud, or fetch images from the network.

## Create a reminder

Open **Coucou → Reminders…** or choose **Reminders** in Settings. Set a title, optional message, date and time, display style, screen, size and position. A card's position is relative to the selected screen; its coordinates range from 0% to 100%.

A reminder can show an SF Symbol or a PNG/JPEG image chosen from the Mac (maximum 2 MB). Card positions are normalized to the selected screen: horizontal position runs left to right, and vertical position runs top to bottom. Add up to three buttons, each with its own title and action:

- **Open link** opens an HTTPS address only, and only after the person clicks the button.
- **Complete** finishes this reminder and stops future repeats.
- **Dismiss** closes this occurrence while keeping a repeating reminder active.
- **Snooze** postpones it by the configured duration; omit it to disable snoozing.
- **Stop repeats** cancels future occurrences.

Press **Escape** to close an alert without choosing a button. A full-screen alert uses a Coucou-owned AppKit panel above normal windows; it cannot cover macOS secure screens such as the login window. Use it only when a strong interruption is intended.

Reminders can run once, daily, on weekdays, or weekly. Coucou checks due times while it is running and schedules native macOS notifications as a fallback. Allow Coucou notifications in System Settings if reminders should still appear when Coucou is closed. macOS Focus and notification preferences can suppress those system banners.

## Connect a local MCP client

In **Settings → Reminders → Connect a local MCP client**, copy the JSON configuration and merge it into the MCP client's configuration. Coucou never edits another app's configuration file. Restart the MCP client after adding the server.

The server uses MCP's standard **stdio** transport. It starts a small Python standard-library adapter installed at:

```text
~/Library/Application Support/NotchBuddy/coucou-mcp.py
```

That adapter sends requests to Coucou over its existing owner-only Unix socket. Keep Coucou running while creating or managing reminders. Available tools are:

- `create_reminder` — create a reminder with its display, schedule, optional image data, snooze, and up to three buttons.
- `list_reminders` — list locally saved reminders.
- `dismiss_reminder` — close the current occurrence while preserving a repeat schedule.
- `complete_reminder` — finish a reminder and cancel its future occurrences.
- `snooze_reminder` — postpone a reminder by a chosen duration, if snooze is enabled for that reminder.
- `stop_reminder` — cancel future occurrences without deleting the record.

The bridge has no shell-execution, file-read, calendar, or arbitrary URL-fetch tool. MCP images are inline PNG/JPEG data capped at 700 KB to fit the local hook message limit; images chosen in Coucou can be up to 2 MB. Links must use HTTPS and open only after a button click. The user's chosen MCP client can still read any information the user asks it to include in a reminder.

This is a **local MCP server**: it works with a client that can launch a stdio server on the same Mac. A hosted/remote Grok bot cannot reach this local process directly; it needs a remote MCP transport or a separately secured relay, neither of which this feature sets up.

## Data and permissions

Reminder records and embedded images are stored in `~/Library/Application Support/NotchBuddy/reminders.json` in the GitHub build, with owner-only directory and file permissions. The App Store build stores them in its sandboxed Application Support directory. They are not uploaded or synced. If the saved file cannot be read, Coucou disables reminder changes rather than replacing it with an empty list; restore or move the file yourself, then restart Coucou. The first reminder asks macOS for notification permission. Denying permission leaves reminders available while Coucou is running, but system banners while it is closed will not be delivered.
