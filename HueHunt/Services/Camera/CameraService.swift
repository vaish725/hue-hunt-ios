import AVFoundation
import Accelerate
import CoreImage
import ImageIO

// A downsampled camera frame in sRGB, ready for palette extraction.
struct PixelSample: Sendable {
  let pixels: [SIMD3<Float>]
}

// Owns the AVCaptureSession and publishes downsampled frames as an async stream.
// Session start/stop and the sample buffer delegate run on dedicated serial queues,
// the one place GCD is used instead of Swift concurrency, since AVCaptureSession
// needs a specific, stable queue rather than actor isolation.
final class CameraService: NSObject, @unchecked Sendable {
  private let session = AVCaptureSession()
  private let sessionQueue = DispatchQueue(label: "com.huehunt.camera.session")
  private let frameQueue = DispatchQueue(label: "com.huehunt.camera.frames")
  private let videoOutput = AVCaptureVideoDataOutput()
  private let minimumFrameInterval: TimeInterval = 0.2
  private var lastFrameDate = Date.distantPast
  private var latestPixelBuffer: CVPixelBuffer?
  private var continuation: AsyncStream<PixelSample>.Continuation?

  private(set) lazy var previewLayer = AVCaptureVideoPreviewLayer(session: session)

  static var authorizationStatus: AVAuthorizationStatus {
    AVCaptureDevice.authorizationStatus(for: .video)
  }

  static func requestAccess() async -> Bool {
    await AVCaptureDevice.requestAccess(for: .video)
  }

  func makeFrameStream() -> AsyncStream<PixelSample> {
    AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
      self.continuation = continuation
    }
  }

  func start() {
    sessionQueue.async { [weak self] in
      self?.configureSessionIfNeeded()
      self?.session.startRunning()
    }
  }

  func stop() {
    sessionQueue.async { [weak self] in
      self?.session.stopRunning()
    }
  }

  // Renders the most recent frame as a JPEG thumbnail scaled so its longest side is
  // maxDimension. Runs on the same queue that writes latestPixelBuffer, so no lock is needed.
  func captureThumbnail(maxDimension: Int = 512, quality: CGFloat = 0.7) async -> Data? {
    await withCheckedContinuation { continuation in
      frameQueue.async { [weak self] in
        guard let pixelBuffer = self?.latestPixelBuffer else {
          continuation.resume(returning: nil)
          return
        }
        let data = Self.makeThumbnailJPEG(
          from: pixelBuffer, maxDimension: maxDimension, quality: quality)
        continuation.resume(returning: data)
      }
    }
  }

  private func configureSessionIfNeeded() {
    guard session.inputs.isEmpty else { return }

    session.beginConfiguration()
    session.sessionPreset = .hd1280x720

    guard
      let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
      let input = try? AVCaptureDeviceInput(device: device),
      session.canAddInput(input)
    else {
      session.commitConfiguration()
      return
    }
    session.addInput(input)

    videoOutput.alwaysDiscardsLateVideoFrames = true
    videoOutput.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ]
    videoOutput.setSampleBufferDelegate(self, queue: frameQueue)
    if session.canAddOutput(videoOutput) {
      session.addOutput(videoOutput)
    }

    session.commitConfiguration()
  }

  private static func makeThumbnailJPEG(
    from pixelBuffer: CVPixelBuffer, maxDimension: Int, quality: CGFloat
  ) -> Data? {
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let extent = ciImage.extent
    let longestSide = max(extent.width, extent.height)
    guard longestSide > 0 else { return nil }
    let scale = CGFloat(maxDimension) / longestSide
    let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
    let qualityOption = CIImageRepresentationOption(
      rawValue: kCGImageDestinationLossyCompressionQuality as String)
    return CIContext().jpegRepresentation(
      of: scaledImage,
      colorSpace: colorSpace,
      options: [qualityOption: quality]
    )
  }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    latestPixelBuffer = pixelBuffer

    let now = Date()
    guard now.timeIntervalSince(lastFrameDate) >= minimumFrameInterval else { return }
    lastFrameDate = now

    guard let pixels = Self.downsample(pixelBuffer) else { return }
    continuation?.yield(PixelSample(pixels: pixels))
  }

  // Scales the frame to 64x64 with vImage and converts BGRA bytes to sRGB floats in 0...1.
  private static func downsample(_ pixelBuffer: CVPixelBuffer) -> [SIMD3<Float>]? {
    let side = 64
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

    guard let sourceAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
    var sourceBuffer = vImage_Buffer(
      data: sourceAddress,
      height: vImagePixelCount(CVPixelBufferGetHeight(pixelBuffer)),
      width: vImagePixelCount(CVPixelBufferGetWidth(pixelBuffer)),
      rowBytes: CVPixelBufferGetBytesPerRow(pixelBuffer)
    )

    var destData = [UInt8](repeating: 0, count: side * side * 4)
    var scaleError = kvImageNoError
    destData.withUnsafeMutableBytes { destBytes in
      guard let destAddress = destBytes.baseAddress else {
        scaleError = kvImageInvalidParameter
        return
      }
      var destBuffer = vImage_Buffer(
        data: destAddress,
        height: vImagePixelCount(side),
        width: vImagePixelCount(side),
        rowBytes: side * 4
      )
      scaleError = vImageScale_ARGB8888(
        &sourceBuffer, &destBuffer, nil, vImage_Flags(kvImageNoFlags))
    }
    guard scaleError == kvImageNoError else { return nil }

    var pixels: [SIMD3<Float>] = []
    pixels.reserveCapacity(side * side)
    for index in 0..<(side * side) {
      let offset = index * 4
      let blue = Float(destData[offset]) / 255
      let green = Float(destData[offset + 1]) / 255
      let red = Float(destData[offset + 2]) / 255
      pixels.append(SIMD3(red, green, blue))
    }
    return pixels
  }
}
