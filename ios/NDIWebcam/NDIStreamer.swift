import Foundation
import CoreMedia
import CoreVideo
import AudioToolbox

// Thread-safe NDI send wrapper.
// All send calls are dispatched on a dedicated serial queue so the
// AVCapture delegate threads never block each other.
final class NDIStreamer {

    enum StreamError: Error {
        case initializationFailed
        case senderCreationFailed
    }

    private(set) var isStreaming = false
    private var sendInstance: NDIlib_send_instance_t?
    private let sendQueue = DispatchQueue(label: "com.ndiwebcam.ndi-send", qos: .userInteractive)

    // MARK: Lifecycle

    func start(sourceName: String) throws {
        guard NDIlib_initialize() else { throw StreamError.initializationFailed }

        var settings = NDIlib_send_create_t()
        let nameBytes = (sourceName as NSString).utf8String
        settings.p_ndi_name = nameBytes
        settings.clock_video = false
        settings.clock_audio = false

        guard let instance = NDIlib_send_create(&settings) else {
            NDIlib_destroy()
            throw StreamError.senderCreationFailed
        }
        sendInstance = instance
        isStreaming = true
    }

    func stop() {
        sendQueue.sync {
            if let instance = sendInstance {
                NDIlib_send_destroy(instance)
                sendInstance = nil
            }
            NDIlib_destroy()
            isStreaming = false
        }
    }

    // MARK: Video

    func sendVideoFrame(_ sampleBuffer: CMSampleBuffer, fps: Int32) {
        guard isStreaming, let instance = sendInstance else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width  = Int32(CVPixelBufferGetWidth(pixelBuffer))
        let height = Int32(CVPixelBufferGetHeight(pixelBuffer))
        let stride = Int32(CVPixelBufferGetBytesPerRow(pixelBuffer))
        let data   = CVPixelBufferGetBaseAddress(pixelBuffer)?.assumingMemoryBound(to: UInt8.self)

        var frame = NDIlib_video_frame_v2_t()
        frame.xres = width
        frame.yres = height
        // Camera2 outputs BGRA; UYVY is more efficient but requires conversion.
        // Using BGRA here avoids an extra conversion pass on the hot path.
        frame.FourCC = NDIlib_FourCC_type_BGRA
        frame.frame_rate_N = fps * 1000
        frame.frame_rate_D = 1000
        frame.picture_aspect_ratio = Float(width) / Float(height)
        frame.frame_format_type = NDIlib_frame_format_type_progressive
        frame.timecode = Int64(bitPattern: 0x8000000000000000) // NDIlib_send_timecode_synthesize
        frame.p_data = data
        frame.line_stride_in_bytes = stride

        sendQueue.async { [instance] in
            NDIlib_send_send_video_v2(instance, &frame)
        }
    }

    // MARK: Audio

    // Expects 32-bit float, non-interleaved (planar) PCM — the format AVCaptureAudioDataOutput delivers.
    func sendAudioFrame(_ sampleBuffer: CMSampleBuffer) {
        guard isStreaming, let instance = sendInstance else { return }

        var blockBuffer: CMBlockBuffer?
        var audioBufferList = AudioBufferList()
        var bufferListSize = MemoryLayout<AudioBufferList>.size

        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: bufferListSize,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard status == noErr else { return }

        guard let format = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
        let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee
        guard let sampleRate = asbd.map({ Int32($0.mSampleRate) }),
              let channels   = asbd.map({ Int32($0.mChannelsPerFrame) }) else { return }

        let sampleCount = Int32(CMSampleBufferGetNumSamples(sampleBuffer))

        // AVCapture delivers float32 interleaved; NDI expects float32 planar (FLTP).
        // For mono/stereo from device mic, de-interleave into planar layout.
        let buffer = audioBufferList.mBuffers
        guard let rawData = buffer.mData else { return }

        var frame = NDIlib_audio_frame_v3_t()
        frame.sample_rate = sampleRate
        frame.no_channels = channels
        frame.no_samples  = sampleCount
        frame.timecode    = Int64(bitPattern: 0x8000000000000000)
        frame.FourCC      = NDIlib_FourCC_audio_type_FLTP
        frame.p_data      = rawData.assumingMemoryBound(to: UInt8.self)
        frame.channel_stride_in_bytes = sampleCount * Int32(MemoryLayout<Float>.size)

        sendQueue.async { [instance] in
            NDIlib_send_send_audio_v3(instance, &frame)
        }
    }

    // MARK: Status

    var connectedReceiverCount: Int {
        guard let instance = sendInstance else { return 0 }
        return Int(NDIlib_send_get_no_connections(instance, 0))
    }
}
