import 'dart:io';
import 'package:image/image.dart';

void main() async {
  final iconsDir = Directory('assets/images/icons');
  if (!await iconsDir.exists()) {
    return;
  }

  await for (final file in iconsDir.list()) {
    if (file is File && file.path.endsWith('.png')) {
      final bytes = await file.readAsBytes();
      final image = decodeImage(bytes);

      if (image == null) {
        continue;
      }

      // Flood fill from corners with tolerance
      // We will identify "background" pixels as those connected to the corners
      // and having a color similar to the corner color.

      final corners = [
        Point(0, 0),
        Point(image.width - 1, 0),
        Point(0, image.height - 1),
        Point(image.width - 1, image.height - 1),
      ];

      final queue = <Point>[];
      final visited = <int>{}; // y * width + x

      // Add corners to queue if they haven't been visited
      for (final corner in corners) {
        final idx = (corner.y * image.width + corner.x).toInt();
        if (!visited.contains(idx)) {
          queue.add(corner);
          visited.add(idx);
        }
      }

      // Also add mid-points of edges
      final edges = [
        Point(image.width ~/ 2, 0),
        Point(image.width ~/ 2, image.height - 1),
        Point(0, image.height ~/ 2),
        Point(image.width - 1, image.height ~/ 2),
      ];

      for (final edge in edges) {
        final idx = (edge.y * image.width + edge.x).toInt();
        if (!visited.contains(idx)) {
          queue.add(edge);
          visited.add(idx);
        }
      }

      // Tolerance for color comparison (0-255)
      // Checkerboard can have quite different colors (white vs gray)
      // But usually they are distinct from the vibrant icon.
      // Let's use a dynamic approach: whatever color is at the corner IS the background color for that region.
      // But checkerboard changes color.
      // So we need to be careful.
      // If we encounter a pixel that is "close enough" to the NEIGHBOR pixel we just came from, we continue?
      // No, that might eat into the image if gradients are smooth.

      // Alternative: Just remove anything that is NOT the icon.
      // The icon is likely centered.
      // Let's assume the background is EITHER white-ish OR gray-ish (checkerboard).
      // Or black (if the user sees black).

      // Let's try to just remove "dark" pixels if the user sees black.
      // But the user said "checkerboard" before.
      // The screenshot shows a dark background with a grid.
      // This suggests the image might be transparent but rendered on black?
      // OR the image has a black background.

      // Let's try to remove black/dark pixels from the outside.

      bool isSimilar(Pixel p1, Pixel p2, int tolerance) {
        return (p1.r - p2.r).abs() <= tolerance &&
            (p1.g - p2.g).abs() <= tolerance &&
            (p1.b - p2.b).abs() <= tolerance;
      }

      // We will use the color of the pixel we are visiting as the reference for its neighbors?
      // No, that causes drift.
      // We should check if the pixel is "background-like".
      // Let's assume background is dark/black based on the screenshot, OR checkerboard.
      // Let's just flood fill anything that is "connected to edge".
      // But we need a stop condition. The stop condition is "hitting a vibrant color".

      // Let's define "vibrant" as having high saturation?
      // Or just different from the start pixel.

      // Let's try a simpler approach:
      // 1. Sample the 4 corners.
      // 2. Flood fill from each corner, replacing pixels that are similar to THAT corner's color.

      final processedImage = image.clone();

      void floodFill(int startX, int startY) {
        final startPixel = image.getPixel(startX, startY);
        // If it's already transparent, stop
        if (startPixel.a == 0) return;

        final q = <Point>[Point(startX, startY)];
        final localVisited = <int>{startY * image.width + startX};

        // Set start pixel to transparent in processed image
        processedImage.setPixelRgba(startX, startY, 0, 0, 0, 0);

        while (q.isNotEmpty) {
          final p = q.removeAt(0);

          final neighbors = [
            Point(p.x + 1, p.y),
            Point(p.x - 1, p.y),
            Point(p.x, p.y + 1),
            Point(p.x, p.y - 1),
          ];

          for (final n in neighbors) {
            if (n.x < 0 ||
                n.x >= image.width ||
                n.y < 0 ||
                n.y >= image.height) {
              continue;
            }

            final idx = n.y.toInt() * image.width + n.x.toInt();
            if (localVisited.contains(idx)) continue;

            final currentPixel = image.getPixel(n.x.toInt(), n.y.toInt());

            // Check if similar to start pixel OR similar to current pixel (to handle gradients in bg)
            // Let's use a tolerance of 40 (out of 255)
            // If the start pixel is white (new icons), we want strict removal of white.
            // If the start pixel is dark (old icons), we want removal of dark.

            bool shouldRemove = false;

            // Check if start pixel is "white-ish"
            if (startPixel.r > 200 &&
                startPixel.g > 200 &&
                startPixel.b > 200) {
              // For white background, be fairly strict but allow some shadow removal
              if (isSimilar(currentPixel, startPixel, 30)) {
                shouldRemove = true;
              }
            } else {
              // For dark background (old icons), use the standard tolerance
              if (isSimilar(currentPixel, startPixel, 40)) {
                shouldRemove = true;
              }
            }

            if (shouldRemove) {
              localVisited.add(idx);
              q.add(n);
              processedImage.setPixelRgba(n.x.toInt(), n.y.toInt(), 0, 0, 0, 0);
            }
          }
        }
      }

      // Run flood fill from all corners
      floodFill(0, 0);
      floodFill(image.width - 1, 0);
      floodFill(0, image.height - 1);
      floodFill(image.width - 1, image.height - 1);

      // Also mid-points
      floodFill(image.width ~/ 2, 0);
      floodFill(image.width ~/ 2, image.height - 1);
      floodFill(0, image.height ~/ 2);
      floodFill(image.width - 1, image.height ~/ 2);

      final encoded = encodePng(processedImage);
      await file.writeAsBytes(encoded);
    }
  }
}
