//
//  ContentView.swift
//  MetalCameraFilter
//
//  Created by Takayuki Sakamoto on 2026/04/17.
//

import SwiftUI
import MetalKit

enum FilterType: String, CaseIterable {
    case normal = "Normal"
    case sepia = "Sepia"
    case mono = "Mono"
    case invert = "Invert"
    
    var rawValueIndex: Int {
        switch self {
        case .normal: return 0
        case .sepia: return 1
        case .mono: return 2
        case .invert: return 3
        }
    }
}

struct ContentView: View {
    
    @State private var selectedFilter: FilterType = .normal
    @State private var intensity: Float = 0.5
    
    @StateObject private var cameraManager = CameraManager()
    @State private var showSaveAlert = false
    
    @State private var isRecording = false
    @State private var showRecordAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            
            MetalCameraView(cameraManager: cameraManager)
                .frame(height: 500)
            
            VStack(spacing: 20) {
                
                Text("Filter: \(selectedFilter.rawValue)")
                    .font(.headline)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(FilterType.allCases, id: \.self) { filter in
                            Button(action: {
                                selectedFilter = filter
                                cameraManager.renderer?.filterType = filter
                            }) {
                                Text(filter.rawValue)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background (
                                        selectedFilter == filter
                                        ? Color.blue
                                        : Color.gray.opacity(0.2)
                                    )
                                    .foregroundColor(
                                        selectedFilter == filter
                                        ? .white
                                        : .primary
                                    )
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                VStack(alignment: .leading) {
                    Text("Intensity: \(String(format: "%.2f", intensity))")
                        .font(.headline)
                    
                    Slider(
                        value: Binding(
                            get: { Double(intensity) },
                            set: {
                                intensity = Float($0)
                                cameraManager.renderer?.intensity = Float($0)
                            }
                        ),
                        in: 0...1
                    )
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 24)
            
            Spacer()
        }
        Button("Save Photo") {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let mtkView = findMTKView(in: window) {
                
                cameraManager.renderer?.saveCurrentFrame(from: mtkView)
                showSaveAlert = true
            }
        }
        .padding()
        .background(Color.green)
        .foregroundColor(.white)
        .cornerRadius(12)
        .alert("保存完了", isPresented: $showSaveAlert) {
            Button("OK", role: .cancel) { }
        }
        
        Button(isRecording ? "Stop Recording" : "Start Recording") {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let mtkView = findMTKView(in: window) {
                
                if isRecording {
                    cameraManager.renderer?.videoRecorder.stopRecording {
                        showRecordAlert = true
                    }
                } else {
                   if let texture = cameraManager.renderer?.currentTexture {
                        let size = CGSize(
                            width: texture.width,
                            height: texture.height
                        )
                       
                       cameraManager.renderer?.videoRecorder.startRecording(
                        size: size,
                       )
                    }
                }
                
                isRecording.toggle()
            }
        }
        .padding()
        .background(isRecording ? Color.red : Color.blue)
        .foregroundColor(.white)
        .cornerRadius(12)
        
        .alert("動画保存完了", isPresented: $showRecordAlert) {
            Button("OK", role: .cancel) { }
        }
        
    }
    
    func findMTKView(in view: UIView) -> MTKView? {
        if let mtkView = view as? MTKView {
            return mtkView
        }
        
        for subview in view.subviews {
            if let found = findMTKView(in: subview) {
                return found
            }
        }
        
        return nil
    }
}


/*
#Preview {
    ContentView()
}
*/
