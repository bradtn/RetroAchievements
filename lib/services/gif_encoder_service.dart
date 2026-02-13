import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;

class GifEncoderService {
  /// Captures multiple frames from a RepaintBoundary and encodes them as a GIF
  ///
  /// [boundaryKey] - GlobalKey for the RepaintBoundary widget
  /// [frameCount] - Number of frames to capture
  /// [delayMs] - Delay between frames in milliseconds (for GIF playback)
  /// [onProgress] - Callback for progress updates (0.0 to 1.0)
  /// [captureFrame] - Async function called before each frame capture to update animation state
  static Future<Uint8List?> captureAnimatedGif({
    required GlobalKey boundaryKey,
    required int frameCount,
    required int delayMs,
    required Future<void> Function(int frameIndex, int totalFrames) captureFrame,
    void Function(double progress)? onProgress,
    double pixelRatio = 2.0,
  }) async {
    final frames = <img.Image>[];

    for (int i = 0; i < frameCount; i++) {
      // Update animation state for this frame
      await captureFrame(i, frameCount);

      // Small delay to let the UI update
      await Future.delayed(const Duration(milliseconds: 16));

      // Capture the frame
      final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) continue;

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) continue;

      // Convert to img.Image
      final imgFrame = img.Image.fromBytes(
        width: image.width,
        height: image.height,
        bytes: byteData.buffer,
        format: img.Format.uint8,
        numChannels: 4,
      );

      frames.add(imgFrame);

      onProgress?.call((i + 1) / frameCount);
    }

    if (frames.isEmpty) return null;

    // Encode as GIF
    final gif = img.GifEncoder();
    for (final frame in frames) {
      gif.addFrame(frame, duration: delayMs ~/ 10); // GIF duration is in 1/100th seconds
    }

    return Uint8List.fromList(gif.finish()!);
  }

  /// Simple version that captures a single animated sequence
  /// Uses pre-rendered frames instead of live capture
  static Future<Uint8List?> encodeFramesToGif({
    required List<Uint8List> pngFrames,
    required int delayMs,
    void Function(double progress)? onProgress,
  }) async {
    final frames = <img.Image>[];

    for (int i = 0; i < pngFrames.length; i++) {
      final decoded = img.decodePng(pngFrames[i]);
      if (decoded != null) {
        frames.add(decoded);
      }
      onProgress?.call((i + 1) / pngFrames.length * 0.5);
    }

    if (frames.isEmpty) return null;

    final gif = img.GifEncoder();
    for (int i = 0; i < frames.length; i++) {
      gif.addFrame(frames[i], duration: delayMs ~/ 10);
      onProgress?.call(0.5 + (i + 1) / frames.length * 0.5);
    }

    return Uint8List.fromList(gif.finish()!);
  }
}
