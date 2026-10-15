// Records one window, alpha included, to a ProRes 4444 .mov with ScreenCaptureKit.
// Neither `screencapture -v` nor Cap keeps a window's transparency; this does, so
// a transparent demo stage comes out as a cut-out.
//
// Usage: record-window <window-id> <seconds> <out.mov>
// Prints FIRST_FRAME_HOST=<seconds> (CACurrentMediaTime base, the same clock the
// demo scene prints its SCENE_START / SCENE_END on) so the take can be cut exactly.
import AppKit
import AVFoundation
import CoreMedia
import Foundation
import QuartzCore
import ScreenCaptureKit

final class Recorder: NSObject, SCStreamOutput, @unchecked Sendable {
    let writer: AVAssetWriter
    let input: AVAssetWriterInput
    let adaptor: AVAssetWriterInputPixelBufferAdaptor
    var started = false
    var frames = 0
    let queue = DispatchQueue(label: "record-window")

    init(url: URL, width: Int, height: Int) throws {
        try? FileManager.default.removeItem(at: url)
        writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.proRes4444,
            AVVideoWidthKey: width, AVVideoHeightKey: height,
        ])
        input.expectsMediaDataInRealTime = true
        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        writer.add(input)
        writer.startWriting()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, buffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let raw = attachments.first?[.status] as? Int,
              SCFrameStatus(rawValue: raw) == .complete,
              let pixels = CMSampleBufferGetImageBuffer(buffer) else { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(buffer)
        if !started {
            writer.startSession(atSourceTime: pts)
            started = true
            print("FIRST_FRAME_HOST=\(pts.seconds)"); fflush(stdout)
        }
        if input.isReadyForMoreMediaData, adaptor.append(pixels, withPresentationTime: pts) { frames += 1 }
    }
}

@main
struct Main {
    static func main() async throws {
        let args = CommandLine.arguments
        guard args.count == 4, let id = UInt32(args[1]), let seconds = Double(args[2]) else {
            FileHandle.standardError.write("usage: record-window <window-id> <seconds> <out.mov>\n".data(using: .utf8)!)
            exit(2)
        }
        _ = await MainActor.run { NSApplication.shared }   // ScreenCaptureKit needs a connection to the window server
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let window = content.windows.first(where: { $0.windowID == id }) else {
            FileHandle.standardError.write("no window \(id)\n".data(using: .utf8)!); exit(1)
        }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let scale = CGFloat(filter.pointPixelScale)
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width * scale)
        config.height = Int(window.frame.height * scale)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.showsCursor = false
        config.ignoreShadowsSingleWindow = true
        config.shouldBeOpaque = false
        config.queueDepth = 8
        let recorder = try Recorder(url: URL(fileURLWithPath: args[3]), width: config.width, height: config.height)
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(recorder, type: .screen, sampleHandlerQueue: recorder.queue)
        try await stream.startCapture()
        try await Task.sleep(for: .seconds(seconds))
        try await stream.stopCapture()
        recorder.queue.sync {}
        recorder.input.markAsFinished()
        await recorder.writer.finishWriting()
        print("FRAMES=\(recorder.frames) SIZE=\(config.width)x\(config.height) STATUS=\(recorder.writer.status.rawValue)")
    }
}
