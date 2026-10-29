# MirrorLink

Mirror an iPhone screen into a web page on your computer, either on your local network or from a hosted website.

## Status: what is tested

- `server.js` and `public/index.html` are complete but were **not run** when written (no package install was possible). Run them first with the checklist below.
- The Swift files in `ios/` are **not compiled or tested on a device**. Expect to fix small Xcode issues.

## Approaches considered

| Approach | Verdict |
|---|---|
| Pure browser (`getDisplayMedia` on iOS Safari) | Not possible. iOS browsers cannot capture the screen. |
| Browser reading the iPhone over USB (QuickTime-style) | Not possible. That device is only visible to native Mac apps. |
| AirPlay receiver (UxPlay, AirServer, Reflector) | Works with no iPhone app, but shows a native window, not a web page. |
| **Companion app (ReplayKit) → WebSocket → web page** | **Chosen.** The only way to put a real live iPhone screen inside a web page. |

## How it works

```
iPhone (ReplayKit extension) --JPEG frames, ws://--> Node relay --> Browser canvas
```

1. The page asks the server for a random 8-character code (valid 10 minutes).
2. You enter the server address and code in the iPhone app and start the broadcast. iOS shows its own permission prompt.
3. The relay accepts only codes the page created, and forwards frames in memory. The page draws them on a canvas.
4. Portrait/landscape follows the frame size. Full screen uses the browser Fullscreen API.

Data transmitted: JPEG screen images, plus a ping for timing. No recording, storage, logging of frames, accounts or analytics. On a LAN the traffic is unencrypted `ws://`. Never expose that plain port to the internet; when hosting online, use the HTTPS/WSS your host provides (see below).

The latency shown is the browser-to-server round trip, not true end-to-end delay.

## Run the server

```bash
npm install
npm start          # http://localhost:3000
```

Needs Node 20.11+. Allow it through your firewall on first run (Windows/macOS prompt).

## Build the iPhone app (Mac with Xcode required)

1. Xcode → New Project → iOS App named **MirrorLink** (SwiftUI). Replace its app file with `ios/MirrorLinkApp.swift`.
2. File → New → Target → **Broadcast Upload Extension** named **MirrorLinkBroadcast** (untick "Include UI Extension"). Replace `SampleHandler.swift` with `ios/SampleHandler.swift`.
3. On **both** targets: Signing & Capabilities → add **App Groups** with the same ID (e.g. `group.com.yourname.mirrorlink`). Update `appGroup` in both Swift files, and `extensionID` in `MirrorLinkApp.swift` to the extension's bundle ID.
4. In the **app** target Info: add `NSLocalNetworkUsageDescription` (any text) and `NSAppTransportSecurity` → `NSAllowsLocalNetworking = YES`. Add the same two keys to the extension's Info.plist.
5. Run on your iPhone (a free Apple ID can sideload to your own device; the build expires after 7 days).

## Use it

1. Open `http://localhost:3000`, click **Connect iPhone**.
2. In the iPhone app enter the address and code shown, tap the broadcast icon → **MirrorLinkBroadcast** → **Start Broadcast**.
3. Stop from the red status bar/Control Center, or click **Disconnect**.

## Put it online as a website

The server is a standard Node app, so any Node host with WebSocket support works (Render, Railway, Fly.io). On Render: push this folder to GitHub → New Web Service → Build command `npm install`, Start command `npm start`. You get an `https://` URL; the page then shows a `wss://your-app...` address to type into the iPhone app. The host sets `PORT` and handles TLS, so no code changes are needed.

- With `wss://` the iPhone app needs no local-network permission or ATS exception.
- Frames pass through the host's server. MirrorLink stores nothing, but you are trusting that host with your screen images.
- Run a single instance only (sessions live in memory).
- Free tiers may sleep when idle, which delays the first connection. Latency is higher than on a LAN.
- Codes are 8 characters, expire after 10 minutes, and the server holds at most 500 open sessions.

## Limits

- Requires installing the companion app. iOS offers no other route to the screen.
- iOS may not broadcast protected video (Netflix etc.) and extensions are limited to about 50 MB of memory, which is why frames are downscaled to 1280 px and sent as JPEG.
- No audio. Same-network only.
- Wi‑Fi with client isolation (some guest/hotel networks) blocks it.

## Simplest option with no coding

Use AirPlay: install [UxPlay](https://github.com/FDH2/UxPlay) (macOS/Linux/Windows) or a paid receiver like AirServer, then Control Center → Screen Mirroring on the iPhone. On a Mac, a USB cable and QuickTime Player → File → New Movie Recording → choose the iPhone also works.
