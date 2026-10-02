# Navigation

October 1, 2026 (user-requested redesign): the signed-in app is a four-tab `TabView`, replacing the single organizer home list. Source is on branch `ui-redesign-tabs`; it has not yet been compiled, tested or accepted on a device.

| Tab | Contents |
| --- | --- |
| Trips | Large-title list of trips (name, route, date range). **+** adds a trip. A row pushes a read-only trip overview — destinations with dates, transport and hotel, travelers, budget summary and notes — whose **Edit** opens the existing trip editor. Empty state offers Add trip and Ask Pip. |
| Pip | Segmented control: **Ask Pip** (typed chat) and **Talk to Pip** (live voice). They remain separate pages sharing one saved conversation; New conversation / New talk sit in the navigation bar. |
| Translate | The two-way interpreter with its language bar. |
| Profile | Profile card, travel companions, nearby address, Language (globe, navigation bar) and Sign out with confirmation. |

Rules kept from the previous design:

- Creating and editing a profile, companion or trip is a modal draft with explicit Save/Cancel, so versioned saves, immutable retries and conflict review are unchanged. `TravelOrganizerView` owns the editor sheet for every tab.
- The microphone is live only while its page is visible. Leaving the Talk to Pip page or the Translate tab stops the session and clears captions, as Done did before. The Ask Pip / Talk to Pip control is disabled during a call so a call is ended explicitly.
- Siri/Shortcuts **Talk to Pip** selects the Pip tab's voice page and starts the call. It waits while an editor or trip-review sheet is open, chat is busy or awaiting retry, or translation is running.
- Ask Pip reloads the shared conversation whenever its page appears, replacing the former **Continue conversation** button.
- The selected tab is restored per scene (`pip.selectedTab`).

Travel companions are managed on the Profile tab and are no longer listed inside the My Profile editor; the trip editor's **Add someone** is unchanged.
