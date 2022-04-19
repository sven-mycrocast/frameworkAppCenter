import Foundation
import AVFoundation;

/**
 This is an example class of playing the live audio stream.
 The live audio stream data is received in AVAUDIOPCMBuffer with 48000khz and 16 pcm data and 960 frames of data
 And played with an AVAudioPlayerNode and AVAudioEngine

 The StreamPlayer reacts on updates for advertisement plays and sets the volume to zero when an advertisement is
 started and afterwards resets the volume to the previous level
 */
public class StreamPlayer: AdPlayStateChangeDelegate {

    private let audioEngine: AVAudioEngine
    private let playerNode: AVAudioPlayerNode
    private let converter: AVAudioConverter

    private let inputFormat: AVAudioFormat
    private let outputFormat: AVAudioFormat

    private let shouldUseBuffer: Bool = true
    private let bufferTime: Double = 120
    private let soundFileUrl: URL = {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("netradio.wav")
    }()

    private var file : AVAudioFile? = nil

    let recordEngine = AVAudioEngine()
    var ringBufferFrameRate: AVAudioFrameCount = 0
    var ringBuffer: [AVAudioPCMBuffer] = []
    var ringBufferSizeInSamples: AVAudioFrameCount = 0

    init() {
        self.audioEngine = AVAudioEngine()
        self.playerNode = AVAudioPlayerNode()
        do {
            let _ = self.audioEngine.mainMixerNode
            self.outputFormat = self.audioEngine.mainMixerNode.outputFormat(forBus: 0)
            self.inputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48000, channels: AVAudioChannelCount(1), interleaved: false)!

            self.converter = AVAudioConverter(from: inputFormat, to: outputFormat)!
            configureAudioSession()

            self.audioEngine.attach(self.playerNode)
            self.audioEngine.connect(self.playerNode, to: self.audioEngine.mainMixerNode, format: nil)
            self.audioEngine.prepare()

            try self.audioEngine.start()

            if shouldUseBuffer {
                startRecording()

                DispatchQueue.main.asyncAfter(deadline: .now() + 2 * bufferTime) {
                    //     print("NetradioStreamPlayer stopping ringbuffer")
                    //     self.stopRecording()
                }
            }
        } catch {
            print("Player error: \(error)")
        }

        Broadcaster.register(AdPlayStateChangeDelegate.self, observer: self)
    }

    deinit {
        Broadcaster.unregister(AdPlayStateChangeDelegate.self, observer: self)
    }

    /**
     Schedule the play of a single buffer of data
     - Parameter buffer:
     */
    func play(_ buffer: AVAudioPCMBuffer) {
        let outputBuffer = AVAudioPCMBuffer(pcmFormat: self.outputFormat, frameCapacity: 960)!

        self.converter.convert(to: outputBuffer, error: nil) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        if shouldUseBuffer {
            self.appendAudioBuffer(outputBuffer)
            return;
        }
        self.playerNode.scheduleBuffer(outputBuffer)
        //let rewindTime: AVAudioTime = AVAudioTime(hostTime: 20)
        //self.playerNode.scheduleBuffer(outputBuffer, at: rewindTime)
        self.playerNode.play()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
        }
    }

    /**
     An advertisement play started, therefore we reduce the volume to zero
     */
    func onAdPlayStarted() {
        self.playerNode.volume = 0
    }

    /**
     Advertisement finished, restore volume to hear the streamer again
     */
    func onAdPlayFinished() {
        self.playerNode.volume = 1
    }


    func startRecording() {
        do {
            try FileManager.default.removeItem(at: self.soundFileUrl)
        } catch let error as NSError {
            print("Error: \(error.domain)")
        }

        let file: String = self.soundFileUrl.absoluteString
                .replacingOccurrences(of: "file://", with: "")
                .replacingOccurrences(of: "netradio.wav", with: "")

        print("NetradioStreamPlayer startRecording for \"netradio.aac\", use Terminal: open \(file)")

        ringBufferFrameRate = 0// AVAudioFrameCount(self.outputFormat.sampleRate * bufferTime)

//        recordEngine.inputNode.installTap(onBus: 0, bufferSize: 512, format: self.outputFormat) { (buffer, time) -> Void in
//            self.appendAudioBuffer(buffer)
//        }

      //  try! recordEngine.start()
    }

    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {

        print("NetradioStreamPlayer appendAudioBuffer(_ buffer: \(buffer.format)")
        ringBuffer.append(buffer)
        ringBufferSizeInSamples += buffer.frameLength

        // throw away old buffers if ring buffer gets too large
        if let firstBuffer = ringBuffer.first {
            if ringBufferSizeInSamples - firstBuffer.frameLength >= ringBufferFrameRate {
                ringBuffer.remove(at: 0)
                ringBufferSizeInSamples -= firstBuffer.frameLength
            }
        }

        print(buffer)
        print(buffer.format)
     //   print(buffer.format.settings)
        let settings: [String: Any] = [
            AVFormatIDKey: buffer.format.settings[AVFormatIDKey] ?? kAudioFormatLinearPCM,
            AVNumberOfChannelsKey: buffer.format.settings[AVNumberOfChannelsKey] ?? 2,
            AVSampleRateKey: buffer.format.settings[AVSampleRateKey] ?? 44100,
            AVLinearPCMBitDepthKey: buffer.format.settings[AVLinearPCMBitDepthKey] ?? 16
        ]
        // write ring buffer to file.
        if (self.file == nil) {
            self.file = try! AVAudioFile(forWriting: self.soundFileUrl, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        }
      //  let file = try! AVAudioFile(forWriting: self.soundFileUrl, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        do {
            print("writing to fl")
            try self.file?.write(from: buffer)
        } catch {
            print(error)
        }

//        for buffer in ringBuffer {
//            do {
//            } catch {
//
//            }
//        }
    }

    func stopRecording() {
        print("NetradioStreamPlayer stopRecording")
        self.file = nil
//        recordEngine.stop()
//
//        let settings: [String: Any] = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC)]
//
//        // write ring buffer to file.
//        let file = try! AVAudioFile(forWriting: self.soundFileUrl, settings: settings)
//        for buffer in ringBuffer {
//            do {
//                try file.write(from: buffer)
//            } catch {
//
//            }
//        }
    }
}
