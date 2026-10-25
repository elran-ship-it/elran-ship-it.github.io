# Don't Forget — iOS app

A dead-simple, niche iOS app for people who keep leaving the house without stuff.

**The mechanic in one line:** your partner (or you) adds an item with a photo or note →
the app nags you gently while you're still at home → the moment you walk out the door
without it, your phone alarms → the only way to silence it is to photograph the item
in your hand.

Built in SwiftUI (iOS 17+), no backend required for v1. Items sync between devices on
the same iCloud account through SwiftData + CloudKit.

---

## How it works

| Situation | What the app does |
|---|---|
| At home, items pending | Repeating "Don't forget: Lunch, Badge" notification every N minutes (default 15) |
| You exit the home geofence with items pending | Burst of 20 time-sensitive notifications 45 s apart (15 min of nagging) + full-screen red alarm with sound when the app is open |
| You photograph the item ("picture it back") | Item confirmed, all alarms cancelled |
| You come back home | Recurring items (keys, badge, wallet) reset to pending; reminders resume |
| Snooze | Quiet for 5 minutes, then the alarms return if anything is still pending |

Partner flow today: "Added by: Me / Partner" toggle on every item. On the same iCloud
account the list is shared across both phones automatically. Cross-account sharing
(partner on their own Apple ID) is the first roadmap item; see below.

## Project layout

```
ios/DontForget/
├── project.yml                  # XcodeGen spec (generates DontForget.xcodeproj)
└── DontForget/
    ├── App/DontForgetApp.swift          # entry point, SwiftData container (iCloud → local fallback)
    ├── Models/ReminderItem.swift        # the one data model
    ├── Models/AppSettings.swift         # UserDefaults keys shared by views and services
    ├── Services/LocationService.swift   # CLLocationManager wrapper: home geofence + one-shot fix
    ├── Services/NotificationService.swift  # home nag + leave-alarm burst + notification actions
    ├── Services/AlarmCoordinator.swift  # glue: geofence events ↔ store ↔ notifications ↔ in-app alarm
    ├── Support/CameraPicker.swift       # UIImagePickerController wrapper (library fallback on Simulator)
    ├── Support/UIImage+Storage.swift    # downscale + JPEG for sync-friendly photos
    └── Views/
        ├── OnboardingView.swift         # 5-screen onboarding (pain → pick items → how it works → permissions → set home)
        ├── ContentView.swift            # main list, status row, swipe actions
        ├── AddItemView.swift            # title / note / photo / added-by / recurring
        ├── ConfirmItemView.swift        # photo-to-confirm
        ├── AlarmView.swift              # full-screen red alarm
        └── SettingsView.swift           # home on a map, radius, intervals, permissions, test alarm
```

## Build it

You need a Mac with Xcode 15.4+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
cd ios/DontForget
xcodegen generate
open DontForget.xcodeproj
```

Then in Xcode:

1. Select the `DontForget` target → Signing & Capabilities → pick your Team.
   (Or put your Team ID in `project.yml` under `DEVELOPMENT_TEAM` and regenerate.)
2. The iCloud container is `iCloud.io.buckleapp.dontforget`. Xcode will offer to create it
   under your team the first time. If you don't want iCloud yet, delete the iCloud lines in
   `project.yml`; the app falls back to a local store automatically.
3. Run on a **real iPhone**. Geofencing works in the Simulator only through
   Features → Location → Custom Location, and the camera doesn't exist there.

### Test the flow on a device

1. Go through onboarding, allow notifications and location. When iOS asks a second time,
   choose **Always** (Settings → Don't Forget → Location → Always if you missed it).
2. Set home while standing in the house.
3. Add "Lunch" with a photo. Within 15 minutes you'll get the first soft reminder.
4. Settings → "Test the leave-home alarm" shows what leaving will feel like.
5. Walk 150+ m away. Expect the alarm within 30 s to a few minutes (iOS geofence latency).
6. Tap the notification → photograph the item → silence.

### Things to know about iOS

- Region monitoring needs **Always** location. Without it the alarm only works while the app is open.
- iOS minimum geofence radius is 100 m. Default is 150 m. Exit detection can take up to a few minutes.
- True alarm-clock behaviour (bypassing silent mode) requires Apple's Critical Alerts
  entitlement, which Apple grants case by case. v1 uses the Time-Sensitive interruption
  level, which breaks through Focus modes but not the mute switch. The 20-notification burst
  is the workaround. Apply for Critical Alerts once the app is live.
- Photos are downscaled to ≤1200 px / JPEG 0.6 before saving so CloudKit sync stays fast.

---

## Why this app, and the playbook from the video

The Starter Story episode you sent is about Lino Leiden's AbMax: a non-technical 18-year-old
shipped a single-purpose fitness app, rebuilt it after two months of over-polishing, and
grew it to roughly $55–60K/month in five months. The parts of that story that apply here:

**1. Niche beats general.** AbMax is not a workout tracker, it's "get visible abs".
Don't Forget is not a to-do app, it's "stop leaving the house without stuff".
Keep it that narrow in the App Store listing, the name and the ads.

**2. The product is simple on purpose.** AbMax = quiz → personalised plan → paywall.
Don't Forget = 5-screen onboarding → set home → photo items → alarm at the door. That is the
whole v1. No categories, no tags, no shared lists with ten people.

**3. Validate before building more.** His "post before building" test: a faceless TikTok
page, 3–4 slideshows a day, CTA "comment APP and I'll send it". For this app, hooks that fit
the format:
- "5 things I forgot this week (and the app that finally stopped it)"
- "My wife puts my lunch in this app and my phone screams at the door if I leave it"
- "POV: you have ADHD and your phone won't let you leave without your keys"
- "Things my partner stopped nagging me about since we got this app"

The ADHD / "I forget everything" audience lives on TikTok and is extremely vocal. That's
the niche; "couples" is the second angle.

**4. Ship in days, not months.** This repo is the "ship" version. Resist adding features
until there is a reaction.

**5. Monetisation.** He used RevenueCat. Suggested model: free for 1 recurring item, Pro
(weekly/yearly) unlocks unlimited items, partner mode and photo confirmation. Paywall
goes after onboarding, before the first alarm (the "aha" moment is leaving home and getting
caught, so a 3-day free trial with the alarm active converts better than a hard paywall).

**6. Growth order he recommends.** Micro-creators (500–1K followers, $100 for 10 videos) to
find a winning hook → UGC at scale via cold-DM'd 5–50K creators → paid ads (TikTok first for
a 15–30 audience, Meta for older) behind the winners → only then polish the product.

**7. His stack, mapped to this app.**

| AbMax | Don't Forget v1 | Later |
|---|---|---|
| Rork / Lovable (vibe-coded React Native) | Native SwiftUI, generated here | — |
| Supabase auth | none needed (iCloud) | Supabase or CloudKit sharing for cross-account partner mode |
| RevenueCat | not wired yet | add RevenueCat SDK + paywall after onboarding |
| PostHog | not wired yet | track: onboarding completion, home set, first item, first alarm, first confirm |
| Sensor Tower | — | check "forgetting things", "ADHD reminder", "leaving home checklist" niches |

---

## Roadmap

**Next (v1.1): partner on a different Apple ID.** Two options:
- CloudKit `CKShare` on a custom zone (free, Apple-native, fiddly). The partner gets an
  invite link, accepts, and can add items from their own phone.
- A tiny Supabase backend with a "household" code. Simpler to reason about, costs money
  at scale, but also unlocks a web/WhatsApp entry point for the partner.

**Then:**
- Multiple places (home, office, gym, parents' house) with per-place items.
- "Bring back" mode: items you must carry *home* (laptop, charger) alarm when leaving the office.
- Shortcuts / Siri: "Hey Siri, don't let me forget the lunch".
- Lock Screen widget with the pending count.
- Weekly "you saved X items" recap (great for sharing on social).

---

## More ideas for remembering stuff (brainstorm)

Stuff that fits the same "catch me at the door" idea and could be v2 features or separate
niche apps:

1. **Partner drop-box.** A shared "I put this on the counter for you" feed. The partner
   photographs the item, the forgetter gets alarmed at the door. This is the strongest
   couples feature and the one in this repo.
2. **Leaving-work checklist.** Reverse geofence: alarm when leaving the office without the
   laptop/charger/badge you brought in.
3. **Car check.** Bluetooth disconnect from the car as the trigger: "Did you take the bag
   from the back seat / the kid from the car seat?" (the car-seat version is a known,
   serious use case).
4. **Smart tags.** Pair with AirTags / Find My items: if the item's tag is not near you
   when you exit, alarm. Removes the need to photograph.
5. **"Did I lock it?" photo log.** Snap the locked door / stove off / iron unplugged on the
   way out; the app timestamps it so you can check later instead of driving back.
6. **Morning routine timer.** Items ordered by departure time: "meds at 7:30, lunch at
   7:50, keys at 8:00" with escalating reminders.
7. **Kids' schedule items.** Swimming kit on Tuesdays, library book on Fridays. Weekly
   recurring items tied to the day, alarm at the school-run exit.
8. **Medication pocket check.** Alarm when leaving without the pills, and a second alarm at
   the time they're due if the pills were never photographed.
9. **Travel packing mode.** Geofence the hotel: alarm when leaving the hotel on checkout day
   if the charger / passport photos aren't confirmed.
10. **"Where did I put it" memory.** Photograph where you left things (glasses, remote,
    passport). Search by name later. Pairs well with the item library you already have.
11. **Forgetting score + streaks.** Days in a row with zero alarms. Shareable, and a cheap
    retention loop.
12. **Voice add for the partner.** "Hey Siri, tell Elran to take the lunch" creates the item
    through an App Intent; no need to open the app.

If you want to pick one to build next, the AirTag-style tag check (4) and the car-seat
check (3) are the two with the clearest emotional pitch for TikTok.
