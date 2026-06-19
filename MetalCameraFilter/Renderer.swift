//
//  Renderer.swift
//  MetalCameraFilter
//
//  Created by Takayuki Sakamoto on 2026/04/23.
//

import Foundation
import MetalKit
import CoreVideo
import UIKit
import Photos

struct FilterUniforms {
    var filterType: Int32
    var intensity: Float
}


struct VertexUniforms {
    var aspectScale: Float
}


final class Renderer: NSObject, MTKViewDelegate {
    
    var filterType: FilterType = .normal
    var intensity: Float = 1.0
    
    let videoRecorder = VideoRecorder()
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState!
    private var textureCache: CVMetalTextureCache?
    
    var currentTexture: MTLTexture?
    
    private weak var mtkView: MTKView?
    
    var filteredTexture: MTLTexture?
    
    init(mtkView: MTKView) {
        guard let device = mtkView.device,
              let commandQueue = device.makeCommandQueue()
        else {
            print("Faild to setup Metal")
            
            self.device = MTLCreateSystemDefaultDevice()!
            self.commandQueue = self.device.makeCommandQueue()!
            
            super.init()
            return
        }
        
        self.device = device
        self.commandQueue = commandQueue
        self.mtkView = mtkView
        
        super.init()
        
        CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            nil,
            device,
            nil,
            &textureCache
        )
        
        buildPipeline()
    }
    
    private func appendVideoFrame(
        texture: MTLTexture,
        time: CFTimeInterval
    ) {
        guard let pixelBuffer = createPixelBuffer(from: texture) else {
            print("Failed to create pixelBuffer")
            return
        }

        let cmTime = CMTime(
            seconds: time,
            preferredTimescale: 600
        )

        videoRecorder.appendFrame(
            pixelBuffer: pixelBuffer,
            withPresentationTime: cmTime
        )
        
    }
    
    private func buildPipeline() {
        guard let library = device.makeDefaultLibrary(),
              let vertexFunction = library.makeFunction(name: "vertexShader"),
              let fragmentFunction = library.makeFunction(name: "fragmentShader")
        else {
            print("Failed to load shaders")
            return
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        do {
            pipelineState = try device.makeRenderPipelineState(
                descriptor: pipelineDescriptor
            )
        } catch {
            print("Failed to create pipeline state: \(error)")
            return
        }
    }
    
    func updateTexture(from pixelBuffer: CVPixelBuffer) {
        guard let textureCache = textureCache else {
            print("Texture cache not found")
            return
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        var cvTexture: CVMetalTexture?
        
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTexture
        )
        
        if status != kCVReturnSuccess {
            print("Failed to create CVMetalTexture")
            return
        }
        
        guard let cvTexture = cvTexture,
              let texture = CVMetalTextureGetTexture(cvTexture) else {
            print("Failed to get MTLTexture")
            return
        }
        
        self.currentTexture = texture
    }
    
    func makeFilteredTexture(width: Int, height: Int) {
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        
        descriptor.usage = [
            .shaderRead,
            .renderTarget
        ]
        
        filteredTexture = device.makeTexture(
            descriptor: descriptor
        )
    }
    
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }
    
    func draw(in view: MTKView) {

        guard let texture = currentTexture,
              let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer()
        else {
            return
        }
        
        /*
        guard let previewEncoder =
            commandBuffer.makeRenderCommandEncoder(
                descriptor: renderPassDescriptor
            )
        else {
            return
        }
         */
        
        if filteredTexture == nil ||
            filteredTexture?.width != texture.width ||
            filteredTexture?.height != texture.height {
            
            makeFilteredTexture(
                width: texture.width,
                height: texture.height
            )
            
            print(                      // ログ用
                "filteredTexture:",
                filteredTexture?.width ?? 0,
                filteredTexture?.height ?? 0
            )
        }
        
        guard let filteredTexture else {
            return
        }
        
        let offscreenPass = MTLRenderPassDescriptor()
        
        offscreenPass.colorAttachments[0].texture = filteredTexture
        offscreenPass.colorAttachments[0].loadAction = .clear
        offscreenPass.colorAttachments[0].storeAction = .store
        offscreenPass.colorAttachments[0].clearColor = MTLClearColorMake(
            0,
            0,
            0,
            1
        )
        
        guard let offscreenEncoder =
            commandBuffer.makeRenderCommandEncoder(
                descriptor: offscreenPass
            )
        else {
            return
        }
        
        var vertexUniforms = VertexUniforms(
            aspectScale: 1.0
        )
        
        offscreenEncoder.setRenderPipelineState(pipelineState)
        
         offscreenEncoder.setVertexBytes(
            &vertexUniforms,
            length: MemoryLayout<VertexUniforms>.stride,
            index: 0
        )

         offscreenEncoder.setFragmentTexture(
            texture,
            index: 0
        )
        
        var uniforms = FilterUniforms(
            filterType: Int32(filterType.rawValueIndex),
            intensity: intensity
        )
        
         offscreenEncoder.setFragmentBytes(
            &uniforms,
            length: MemoryLayout<FilterUniforms>.stride,
            index: 0
        )

         offscreenEncoder.drawPrimitives(
            type: .triangleStrip,
            vertexStart: 0,
            vertexCount: 4
        )

         offscreenEncoder.endEncoding()
         

        if videoRecorder.recording {
            let time = CACurrentMediaTime()

            appendVideoFrame(
                texture: filteredTexture,
                time: time
            )
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func saveCurrentFrame(from mtkView: MTKView) {
        let renderer = UIGraphicsImageRenderer(size: mtkView.bounds.size)

        let image = renderer.image { _ in
            mtkView.drawHierarchy(
                in: mtkView.bounds,
                afterScreenUpdates: true
            )
        }

        UIImageWriteToSavedPhotosAlbum(
            image,
            nil,
            nil,
            nil
        )

    }
    
    func createPixelBuffer(from texture: MTLTexture) -> CVPixelBuffer? {
        let width = texture.width
        let height = texture.height
        
        var pixelBuffer: CVPixelBuffer?
        
        let attrs: [CFString: Any] = [
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )
        
        guard let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        
        let region = MTLRegionMake2D(0, 0, width, height)
        
        texture.getBytes(
                CVPixelBufferGetBaseAddress(buffer)!,
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                from: region,
                mipmapLevel: 0
        )
        
        CVPixelBufferUnlockBaseAddress(buffer, [])
    
        return buffer
    }
    
    
}
