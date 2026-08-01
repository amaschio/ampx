import AVFoundation
import os

/// Realtime-safe PCM capture for an `AVAudioNode` tap.
///
/// The audio I/O thread must not allocate. `capture` only `memcpy`s into preallocated
/// storage under an unfair lock; `makePCMBuffer` (called on a processing queue) may
/// allocate / reuse an `AVAudioPCMBuffer` for analysis APIs that still expect one.
final class TapPCMStaging: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock()
    private let capacity: Int
    private var left: [Float]
    private var right: [Float]
    private var frameLength = 0
    private var channelCount = 1
    private var sampleRate: Double = 44_100
    private var cachedBuffer: AVAudioPCMBuffer?

    init(capacity: Int = 8192) {
        self.capacity = max(256, capacity)
        self.left = [Float](repeating: 0, count: self.capacity)
        self.right = [Float](repeating: 0, count: self.capacity)
    }

    /// Called from the tap callback — no heap allocation.
    func capture(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return }

        let channels = Int(buffer.format.channelCount)
        let n = min(frames, self.capacity)
        let start = frames - n
        let byteCount = n * MemoryLayout<Float>.size

        self.lock.lock()
        self.frameLength = n
        self.channelCount = max(1, channels)
        self.sampleRate = buffer.format.sampleRate
        self.left.withUnsafeMutableBufferPointer { dst in
            guard let base = dst.baseAddress else { return }
            memcpy(base, channelData[0].advanced(by: start), byteCount)
        }
        self.right.withUnsafeMutableBufferPointer { dst in
            guard let base = dst.baseAddress else { return }
            if channels > 1 {
                memcpy(base, channelData[1].advanced(by: start), byteCount)
            } else {
                memcpy(base, channelData[0].advanced(by: start), byteCount)
            }
        }
        self.lock.unlock()
    }

    /// Builds (or reuses) a PCM buffer on the analysis queue.
    func makePCMBuffer() -> AVAudioPCMBuffer? {
        self.lock.lock()
        defer { self.lock.unlock() }

        let frames = self.frameLength
        let channels = self.channelCount
        let rate = self.sampleRate
        guard frames > 0,
              let format = AVAudioFormat(
                  commonFormat: .pcmFormatFloat32,
                  sampleRate: rate,
                  channels: AVAudioChannelCount(channels),
                  interleaved: false
              )
        else {
            return nil
        }

        let needsNew = self.cachedBuffer == nil
            || self.cachedBuffer?.format != format
            || Int(self.cachedBuffer?.frameCapacity ?? 0) < frames
        if needsNew {
            self.cachedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))
        }
        guard let out = self.cachedBuffer, let dst = out.floatChannelData else {
            return nil
        }
        out.frameLength = AVAudioFrameCount(frames)
        let byteCount = frames * MemoryLayout<Float>.size
        self.left.withUnsafeBufferPointer { src in
            guard let base = src.baseAddress else { return }
            memcpy(dst[0], base, byteCount)
        }
        if channels > 1 {
            self.right.withUnsafeBufferPointer { src in
                guard let base = src.baseAddress else { return }
                memcpy(dst[1], base, byteCount)
            }
        }
        return out
    }
}
