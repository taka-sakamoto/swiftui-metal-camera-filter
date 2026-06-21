//
//  CameraManager.swift
//  MetalCameraFilter
//
//  Created by Takayuki Sakamoto on 2026/04/23.
//

import Foundation
import AVFoundation
import Combine

final class CameraManager: NSObject, ObservableObject {
    
    let session = AVCaptureSession()
    let videoOutput = AVCaptureVideoDataOutput()
    private var isConfigured = false
    
    weak var renderer: Renderer?
    
    override init() {
        super.init()
    }
    
    func setupCamera() {
        
        if isConfigured {
            return
        }
        
        isConfigured = true
        
        session.beginConfiguration()
        session.sessionPreset = .high
        
        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ),
        let input = try? AVCaptureDeviceInput(device: device)
        else {
            print("Camera device error")
            session.commitConfiguration()
            return
        }
        
        // input
        if session.inputs.isEmpty,
           session.canAddInput(input) {
            session.addInput(input)
            print("Input added")
        } else {
            print("Cannot add input")
        }
        
        // Output settings
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_32BGRA
        ]
        
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        videoOutput.setSampleBufferDelegate(
            self,
            queue: DispatchQueue(label: "camera.frame.queue")
        )
        
        // Output
        if session.outputs.isEmpty,
           session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            
        } else {
            print("Cannot add output")
        }
        
        // Orientation 重要
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }

        session.commitConfiguration()
        
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
        
            return
        }
        
        renderer?.updateTexture(from: pixelBuffer)
    }
}
