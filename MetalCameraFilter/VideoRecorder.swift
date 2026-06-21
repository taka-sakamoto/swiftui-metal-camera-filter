//
//  VideoRecorder.swift
//  MetalCameraFilter
//
//  Created by Takayuki Sakamoto on 2026/04/28.
//

import Foundation
import AVFoundation
import UIKit

final class VideoRecorder {
    private var assetWriter: AVAssetWriter?
    private var writerInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    private var isRecording = false
    private var startTime: CMTime?
    
    private var frameCount: Int64 = 0
    private let fps: Int32 = 30
    
    private var outputURL: URL {
        let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        
        return documents.appendingPathComponent("filtered_video.mp4")
    }
    
    var recording: Bool {
        return isRecording
    }
    
    func startRecording(size: CGSize) {
        do {
            // 既存ファイル削除
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.removeItem(at: outputURL)
            }

            assetWriter = try AVAssetWriter(
                outputURL: outputURL,
                fileType: .mp4
            )
            
            let settings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(size.width),
                AVVideoHeightKey: Int(size.height),
                
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 6_000_000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                ]
            ]
            
            writerInput = AVAssetWriterInput(
                mediaType: .video,
                outputSettings: settings
            )
            
            writerInput?.expectsMediaDataInRealTime = true
            writerInput?.transform = .identity
            
            let attributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String:
                    Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String:
                    size.width,
                kCVPixelBufferHeightKey as String:
                    size.height
            ]
            
            if let writer = assetWriter,
               let input = writerInput,
               writer.canAdd(input) {

                writer.add(input)

                
                pixelBufferAdaptor =
                    AVAssetWriterInputPixelBufferAdaptor(
                        assetWriterInput: input,
                        sourcePixelBufferAttributes: attributes
                    )
                
                writer.startWriting()
                writer.startSession(atSourceTime: .zero)
                
                isRecording = true
                startTime = nil
                
            }
        } catch {
            print("failed to start recording: \(error)")
        }
        
        frameCount = 0
        
    }
    
    func stopRecording(completion: @escaping () -> Void) {
        guard isRecording else { return }
        
        isRecording = false
        writerInput?.markAsFinished()
        
        assetWriter?.finishWriting { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                
                if let error = self.assetWriter?.error {
                    print("Writer error: \(error.localizedDescription)")
                }
        
                let path = self.outputURL.path
            
            
                if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(path) {
                    UISaveVideoAtPathToSavedPhotosAlbum(
                        path,
                        nil,
                        nil,
                        nil
                    )
                
                    print("Saved to Photos")
                } else {
                    print("Still NOT compatible")
                }
                
                completion()
            }
        }
        
    }
    
    func appendFrame(
        pixelBuffer: CVPixelBuffer,
        withPresentationTime time: CMTime
    ) {
        guard isRecording,
              let input = writerInput,
              let adaptor = pixelBufferAdaptor,
              input.isReadyForMoreMediaData
        else {
            return
        }
        
 
        let presentationTime = CMTime(
            value: frameCount,
            timescale: fps
        )
        
        frameCount += 1
        
        adaptor.append(
            pixelBuffer,
            withPresentationTime: presentationTime
        )

    }
}
