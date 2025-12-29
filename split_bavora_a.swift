import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let inputPath = "/Users/selimyay/cebinden/assets/car_images/bavora/a_series/a_series.png"
let outputDir = "/Users/selimyay/cebinden/assets/car_images/bavora/a_series/"
let fileManager = FileManager.default

// Ensure output directory exists
if !fileManager.fileExists(atPath: outputDir) {
    try fileManager.createDirectory(atPath: outputDir, withIntermediateDirectories: true, attributes: nil)
}

guard let dataProvider = CGDataProvider(filename: inputPath),
      let image = CGImage(jpegDataProviderSource: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) ?? CGImage(pngDataProviderSource: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
    print("Failed to load image")
    exit(1)
}

let width = image.width
let height = image.height
let cols = 2
let rows = 3
let tileWidth = width / cols
let tileHeight = height / rows

print("Image dimensions: \(width)x\(height)")
print("Tile dimensions: \(tileWidth)x\(tileHeight)")

for row in 0..<rows {
    for col in 0..<cols {
        let x = col * tileWidth
        let y = row * tileHeight
        let rect = CGRect(x: x, y: y, width: tileWidth, height: tileHeight)
        
        guard let cropped = image.cropping(to: rect) else {
            print("Failed to crop image at \(x),\(y)")
            continue
        }
        
        let index = (row * cols) + col + 1
        let outputPath = outputDir + "a_series_\(index).png"
        let url = URL(fileURLWithPath: outputPath)
        
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            print("Failed to create destination for \(outputPath)")
            continue
        }
        
        CGImageDestinationAddImage(destination, cropped, nil)
        if CGImageDestinationFinalize(destination) {
            print("Saved \(outputPath)")
        } else {
            print("Failed to save \(outputPath)")
        }
    }
}
