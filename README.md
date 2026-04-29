# SwiftUI Metal Camera Filter

A real-time camera filter app built with SwiftUI, AVFoundation, and Metal.
This app allows users to preview live camera input with real-time Metal-based filters, 
adjust filter intensity, and save filtered photos and videos directly to the Photos app.

## Features

- Real-time camera preview using AVFoundation
- Metal-based image filters (Sepia, Invert, etc.)
- Filter intensity control with slider
- Save filtered photos to Photos
- Save filtered videos to Photos
- Real-time video recording with applied filters
- iOS 17 compatible camera rotation handling

## Tech Stack
- SwiftUI
- Metal / MetalKit
- AVFoundation
- AVAssetWriter
- Photos Framework

## Challenges

The most challenging part of this project was implementing filtered video recording.

Saving photos after applying filters was straightforward, but saving filtered videos required capturing
the rendered Metal output instead of the original camera frames.

I solved this by using `drawable.texture` from `MTKView` and converting it into video frames for 
`AVAssetWriter`, allowing the recorded video to preserve the real-time Metal filter effects.

I also improved app stability by fixing AVCaptureSession configuration issues and handling camera
orientation properly for iOS 17.

## What I Learned

- Real-time camera processing with AVFoundation
- Metal texture rendering pipeline
- Saving rendered textures as video using AVAssetWriter
- Managing AVCaptureSession safely in SwiftUI
- Handling camera rotation and iOS 17 API updates
- Future Improvements
- REC indicator during video recording
- More filter variations
- Front camera support
- Better recording performance optimization

## Screenshots

(Add app screenshots here)
