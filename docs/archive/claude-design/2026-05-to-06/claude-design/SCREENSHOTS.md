# Capturing current screenshots

**There is nothing to screenshot.** The Sideline has no code yet — this design pass *precedes* the build. Unlike the user's other apps (where you'd boot the simulator and capture the stock UI to redesign), here you are designing from a blank slate.

## What that means for you
- The `screens-to-design/` briefs and the sample briefing JSON in `02_today_briefing.md` are the **only** source of truth. There is no "current state" to react against.
- Design the populated state first and best, then derive skeleton / offline / error / free-limited from it.
- Don't ask for screenshots; there are none to give until after your designs are implemented.

## After implementation (informational only — not your job now)
Once the engineer builds your screens, the verification loop will capture:
```sh
cd /Users/jackwallner/glptracker
xcodegen generate
xcodebuild -project Sideline.xcodeproj -scheme Sideline \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
xcrun simctl boot 'iPhone 17 Pro'; open -a Simulator
xcrun simctl install booted <DerivedData>/Sideline.app
xcrun simctl launch booted com.jackwallner.sideline
xcrun simctl io booted screenshot claude-design/screenshots/02_today_briefing.png
```
If, after implementation, Jack wants a revision, you'll get a same-named brief plus a real screenshot at that point. Until then: design from spec.

## App Store screenshots
Marketing/App Store screenshots are a **separate job**, not part of this handoff. Do not produce 1290×2796 store frames here. (They're listed in the build plan's fastlane phase, generated later from the finished UI.)
