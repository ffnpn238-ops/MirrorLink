// Target: Broadcast Upload Extension ("MirrorLinkBroadcast"). Captures the screen with ReplayKit,
// encodes JPEG frames, and sends them over a WebSocket to the MirrorLink server.
import ReplayKit
import CoreImage
import ImageIO

let appGroup = "group.com.example.mirrorlink"   // change to your own App Group ID

class SampleHandler: RPBroadcastSampleHandler {
    private var task: URLSessionWebSocketTask?
    private let context = CIContext()
    private var lastSent = CFAbsoluteTimeGetCurrent()
    private var inFlight = false
    private let maxFPS = 20.0
    private let maxSide: CGFloat = 1280

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        let d = UserDefaults(suiteName: appGroup)
        guard let host = d?.string(forKey: "host"), let code = d?.string(forKey: "code"),
              let url = URL(string: "\(host)/ingest?code=\(code.trimmingCharacters(in: .whitespaces).uppercased())") else {
            finishBroadcastWithError(NSError(domain: "MirrorLink", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Open MirrorLink and enter the server address and code first."]))
            return
        }
        task = URLSession.shared.webSocketTask(with: url)
        task?.resume()
        listen()
    }

    // Detect the server closing the socket (bad code, session ended).
    private func listen() {
        task?.receive { [weak self] result in
            if case .failure(let e) = result { self?.finishBroadcastWithError(e) } else { self?.listen() }
        }
    }

    override func broadcastFinished() {
        task?.cancel(with: .goingAway, reason: nil)
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with type: RPSampleBufferType) {
        guard type == .video, !inFlight, let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastSent >= 1.0 / maxFPS else { return }
        lastSent = now

        var image = CIImage(cvPixelBuffer: pixels)
        if let n = CMGetAttachment(sampleBuffer, key: RPVideoSampleOrientationKey as CFString, attachmentModeOut: nil) as? NSNumber,
           let o = CGImagePropertyOrientation(rawValue: n.uint32Value) {
            image = image.oriented(o)   // gives portrait/landscape correctly
        }
        let scale = min(1, maxSide / max(image.extent.width, image.extent.height))
        image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let jpeg = context.jpegRepresentation(
            of: image, colorSpace: CGColorSpaceCreateDeviceRGB(),
            options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.6]) else { return }

        inFlight = true
        task?.send(.data(jpeg)) { [weak self] error in
            self?.inFlight = false
            if let error { self?.finishBroadcastWithError(error) }
        }
    }
}
