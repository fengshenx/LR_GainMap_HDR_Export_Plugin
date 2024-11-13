//
//  main.swift
//  PQHDR_to_GainMapHDR
//  This code will read a image file as both SDR and HDR image, then calculate difference between
//  two images as gain map. After denoise and gamma adjustment, combine SDR image with gain map
//  to get GainMapHDR file.
//
//  Created by Luyao Peng on 2024/9/27.
//

import CoreImage
import ImageIO
import CoreGraphics
import Foundation
import CoreImage.CIFilterBuiltins
import UniformTypeIdentifiers

let ctx = CIContext()

func subtractBlendMode(inputImage: CIImage, backgroundImage: CIImage) -> CIImage {
    let colorBlendFilter = CIFilter.subtractBlendMode()
    colorBlendFilter.inputImage = inputImage
    colorBlendFilter.backgroundImage = backgroundImage
    return colorBlendFilter.outputImage!
}

func linearTosRGB(inputImage: CIImage) -> CIImage {
    let linearTosRGB = CIFilter.linearToSRGBToneCurve()
    linearTosRGB.inputImage = inputImage
    return linearTosRGB.outputImage!
}

func exposureAdjust(inputImage: CIImage, inputEV: Float) -> CIImage {
    let exposureAdjustFilter = CIFilter.exposureAdjust()
    exposureAdjustFilter.inputImage = inputImage
    exposureAdjustFilter.ev = inputEV
    return exposureAdjustFilter.outputImage!
}

func maximumComponent(inputImage: CIImage) -> CIImage {
    let maximumComponentFilter = CIFilter.maximumComponent()
    maximumComponentFilter.inputImage = inputImage
    return maximumComponentFilter.outputImage!
}

func toneCurve1(inputImage: CIImage) -> CIImage {
    let toneCurveFilter = CIFilter.toneCurve()
    toneCurveFilter.inputImage = inputImage
    toneCurveFilter.point0 = CGPoint(x: 0.1, y: 0.0)
    toneCurveFilter.point1 = CGPoint(x: 0.55, y: 0.5)
    toneCurveFilter.point2 = CGPoint(x: 1, y: 1)
    return toneCurveFilter.outputImage!
}

func toneCurve2(inputImage: CIImage) -> CIImage {
    let toneCurveFilter = CIFilter.toneCurve()
    toneCurveFilter.inputImage = inputImage
    toneCurveFilter.point0 = CGPoint(x: 0, y: 0.75)
    toneCurveFilter.point1 = CGPoint(x: 0.6, y: 0.77)
    toneCurveFilter.point2 = CGPoint(x: 0.95, y: 0.95)
    toneCurveFilter.point3 = CGPoint(x: 0.99, y: 0.99)
    return toneCurveFilter.outputImage!
}

func hdrtosdr(inputImage: CIImage) -> CIImage {
    let imagedata = ctx.tiffRepresentation(of: inputImage,
                                           format: CIFormat.RGBA8,
                                           colorSpace: CGColorSpace(name: CGColorSpace.displayP3)!
    )
    let sdrimage = CIImage(data: imagedata!)
    return sdrimage!
}

// 解析命令行参数
func parseArguments() -> (source: String, destination: String, quality: Float) {
    var quality: Float = 0.8 // 默认质量
    var sourcePath: String?
    let args = Array(CommandLine.arguments.dropFirst()) // 改为 let 常量
    
    var i = 0
    while i < args.count {
        switch args[i] {
        case "-q":
            if i + 1 < args.count, 
               let qValue = Float(args[i + 1]), 
               qValue >= 0.0, qValue <= 1.0 {
                quality = qValue
                i += 2
            } else {
                print("Invalid quality value. Must be between 0.0 and 1.0")
                exit(1)
            }
        case "-i":
            if i + 1 < args.count {
                sourcePath = args[i + 1]
                i += 2
            } else {
                print("Missing input file path after -i")
                exit(1)
            }
        default:
            i += 1
        }
    }
    
    // 检查必需参数
    guard let source = sourcePath, args.last != "-i", args.last != "-q" else {
        print("Usage: program -i <source file> [-q quality] <destination>")
        print("  -i: input HDR image file")
        print("  -q: HEIF compression quality (0.0-1.0, default: 0.8)")
        exit(1)
    }
    
    // 最后一个参数作为目标路径
    let destination = args.last!
    
    return (source, destination, quality)
}

let (sourcePath, destinationPath, quality) = parseArguments()
let url_hdr = URL(fileURLWithPath: sourcePath)
let path_export = URL(fileURLWithPath: destinationPath)

let hdrimage = CIImage(contentsOf: url_hdr,options: [.expandToHDR: true])
let tonemapping_sdrimage = hdrimage?.applyingFilter("CIToneMapHeadroom", parameters: ["inputTargetHeadroom":1.0])

let sdrimage = hdrtosdr(inputImage:hdrimage!)
let gainmap = toneCurve2(
    inputImage:toneCurve1(
        inputImage:maximumComponent(
            inputImage:exposureAdjust(
                inputImage:linearTosRGB(
                    inputImage:subtractBlendMode(
                        inputImage:exposureAdjust(inputImage:sdrimage,inputEV: -3.5),backgroundImage: exposureAdjust(inputImage:hdrimage!,inputEV: -3.5)
                    )
                ), inputEV: 0.5
            )
        )
    )
)

// codes below from: https://gist.github.com/kiding/fa4876ab4ddc797e3f18c71b3c2eeb3a?permalink_comment_id=4289828#gistcomment-4289828

// Get metadata, and especially the {MakerApple} tags from the main image.
var imageProperties = tonemapping_sdrimage!.properties
var makerApple = imageProperties[kCGImagePropertyMakerAppleDictionary as String] as? [String: Any] ?? [:]

// Set HDR-related tags as desired.
makerApple["33"] = 4.0 // 0x21, seems to describe the global HDR headroom. Can be 0.0 or un-set when setting the tag below.
makerApple["48"] = 0.0 // 0x30, seems to describe the effect of the gain map to the HDR effect, between 0.0 and 8.0 with 0.0 being the max.

// Set metadata back on image before export.
imageProperties[kCGImagePropertyMakerAppleDictionary as String] = makerApple
let modifiedImage = tonemapping_sdrimage!.settingProperties(imageProperties)

do {
    try ctx.writeHEIFRepresentation(of: modifiedImage,
                                    to: path_export,
                                    format: CIFormat.RGBA8,
                                    colorSpace: (sdrimage.colorSpace)!,
                                    options: [
                                        .hdrGainMapImage: gainmap,
                                        CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): quality
                                    ])
} catch {
    print("Error saving image: \(error.localizedDescription)")
    exit(1)
}
