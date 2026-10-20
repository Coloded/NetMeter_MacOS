import Foundation
import CoreGraphics
import ImageIO

// Exact crops from the supplied screenshot. UI pixels and values are preserved.
let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("docs/screenshots")
let original = directory.appendingPathComponent("graph-stack-ru.png")
guard let source = CGImageSourceCreateWithURL(original as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("Cannot open screenshot") }
precondition(image.width == 572 && image.height == 1834, "Crop coordinates require the original 572 × 1834 screenshot")
let crops = [("cpu", 0, 371), ("network", 371, 364), ("memory", 735, 366), ("gpu", 1101, 363), ("disk", 1464, 370)]
for (name, top, height) in crops {
    guard let cropped = image.cropping(to: CGRect(x: 0, y: top, width: image.width, height: height)),
          let destination = CGImageDestinationCreateWithURL(directory.appendingPathComponent("\(name)-ru.png") as CFURL, "public.png" as CFString, 1, nil) else {
        fatalError("Cannot crop \(name)")
    }
    CGImageDestinationAddImage(destination, cropped, nil)
    precondition(CGImageDestinationFinalize(destination))
    print("Prepared \(name)-ru.png (\(cropped.width) × \(cropped.height))")
}
