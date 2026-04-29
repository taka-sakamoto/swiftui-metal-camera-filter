//
//  CameraView.swift
//  MetalCameraFilter
//
//  Created by Takayuki Sakamoto on 2026/04/17.
//

import SwiftUI
import AVFoundation

struct CameraView: UIViewRepresentable {
    let session = AVCaptureSession()
    
    func makeUIView(context: Context) -> CameraPreviewView {
        let view  = CameraPreviewView()
        
        checkCameraPermission(for: view)
        
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
    }
    
    func checkCameraPermission(for view: CameraPreviewView) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("Camera auth status: \(status.rawValue)")
        
        switch status {
            
        case .authorized:
            print("authorized")
            setupCamera(for: view)
            
        case .notDetermined:
            print("noDetermined → requesting access")
            
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.setupCamera(for: view)
                    } else {
                        print("Camera permission denied")
                    }
                }
            }
        case .denied:
            print("denied")
            
        case .restricted:
            print("restricted")
            
        @unknown default:
            print("unknown")
        }
    }
    
    private func setupCamera(for view: CameraPreviewView) {
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ),
        let input = try? AVCaptureDeviceInput(device: device)
        else {
            print("Camera device error")
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill

        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }
}

/*
#Preview {
    CameraView()
}
*/
