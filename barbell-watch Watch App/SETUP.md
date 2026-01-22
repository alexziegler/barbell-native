# BarbellWatch Setup Guide

This guide explains how to complete the Apple Watch app setup in Xcode.

## Step 1: Add Watch Target

1. Open `barbell-native.xcodeproj` in Xcode
2. Go to **File > New > Target**
3. Select **watchOS > Watch App**
4. Configure:
   - Product Name: `BarbellWatch`
   - Bundle Identifier: `alexziegler.barbell-native.watchkitapp`
   - Language: Swift
   - User Interface: SwiftUI
   - Watch App: **Watch App**
   - Include Notification Scene: No
   - Include Complication: Optional
5. Click **Finish**
6. When prompted about activating the scheme, click **Activate**

## Step 2: Remove Auto-Generated Files

Xcode creates default files that we'll replace with our existing ones:

1. Delete the auto-generated files in the BarbellWatch group:
   - `BarbellWatchApp.swift` (we have our own)
   - `ContentView.swift` (we have our own)
   - Any other auto-generated Swift files

## Step 3: Add Existing Source Files

Add these files to the **BarbellWatch** target:

### From `BarbellWatch/`:
- `BarbellWatchApp.swift`
- `ContentView.swift`

### From `BarbellWatch/WatchConnectivity/`:
- `WatchSessionManager.swift`

### From `BarbellWatch/Views/`:
- `QuickLogView.swift`
- `RestTimerView.swift`
- `TodaySummaryView.swift`

### From `BarbellWatch/Theme/`:
- `WatchTheme.swift`

### From `Shared/`:
- `WatchMessages.swift` (add to BOTH iOS and watchOS targets)

**To add files:**
1. Right-click the BarbellWatch group in Xcode
2. Select **Add Files to "barbell-native"**
3. Select the files
4. Ensure **BarbellWatch** target is checked
5. Click **Add**

## Step 4: Add Shared Files to iOS Target

The `Shared/WatchMessages.swift` file needs to be in both targets:

1. Select `WatchMessages.swift` in the Project Navigator
2. In the File Inspector (right panel), under **Target Membership**
3. Check both `barbell-native` (iOS) and `BarbellWatch` (watchOS)

## Step 5: Add WatchConnectivity Framework

### For iOS Target:
1. Select the project in Project Navigator
2. Select `barbell-native` target
3. Go to **General > Frameworks, Libraries, and Embedded Content**
4. Click **+** and add `WatchConnectivity.framework`

### For watchOS Target:
1. Select `BarbellWatch` target
2. Go to **General > Frameworks, Libraries, and Embedded Content**
3. Click **+** and add `WatchConnectivity.framework`

## Step 6: Configure Build Settings

### iOS Target:
1. Select `barbell-native` target
2. Go to **Build Settings**
3. Search for "Other Linker Flags"
4. Add `-framework WatchConnectivity` if not already present

### watchOS Target:
1. Select `BarbellWatch` target
2. Go to **Build Settings**
3. Set **Deployment Target** to `10.0` or higher

## Step 7: Configure WatchKit Companion

1. Select the iOS `barbell-native` target
2. Go to **General > Frameworks, Libraries, and Embedded Content**
3. Ensure `BarbellWatch.app` is listed with **Embed & Sign**

## Step 8: Add iPhone-side WatchConnectivity

Add to **iOS target only**:

1. Right-click `barbell-native` group
2. Add Files → select `barbell-native/WatchConnectivity/WatchSessionManager.swift`
3. Ensure only `barbell-native` (iOS) target is checked

## Step 9: Verify Configuration

1. Select a paired Watch + iPhone simulator
2. Build and run the iOS app (Cmd+R)
3. The Watch app should automatically install on the paired Watch simulator

## Testing

1. **Test on Simulators:**
   - Open Xcode's Devices and Simulators (Window > Devices and Simulators)
   - Pair an iPhone simulator with a Watch simulator

2. **Test Connectivity:**
   - Run iOS app on iPhone simulator
   - Run Watch app on Watch simulator
   - Exercises should sync from iPhone to Watch

3. **Test Logging:**
   - Log a set from Watch
   - Verify it appears on iPhone

## Troubleshooting

### "WatchConnectivity not supported"
- Ensure you're running on a real device or properly paired simulators
- Check that WatchConnectivity framework is added to both targets

### "iPhone not reachable"
- Make sure the iPhone app is running
- Check that both devices are paired
- Verify WCSession is activated on both sides

### Sets not syncing
- Check that LogService is properly shared via environment
- Verify WatchSessionManager.shared is configured in barbell_nativeApp.swift
