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
import Foundation

let ctx = CIContext()

let allArgs = Array(CommandLine.arguments.dropFirst())
let imageoptions = Array(allArgs.dropLast())
let outputFile = allArgs.last

var imagequality: Double? = 0.85
var sdr_export: Bool = false
var pq_export: Bool = false
var hlg_export: Bool = false
var bit_depth = CIFormat.RGBA8
var url_hdr: URL? = nil
var url_export_heic: URL? = nil

var index:Int = 0
while index < imageoptions.count {
    let option = imageoptions[index]
    switch option {
    case "-q":
        guard index + 1 < imageoptions.count else {
            print("Error: The -q option requires a valid numeric value.")
            exit(1)
        }
        if let value = Double(imageoptions[index + 1]) {
            if value > 1 {
                imagequality = value/100
            } else {
                imagequality = value
            }
            index += 1
        } else {
            print("Error: The -q option requires a valid numeric value.")
            exit(1)
        }
    case "-i":
        guard index + 1 < imageoptions.count else {
            print("Error: The -i option requires an input file.")
            exit(1)
        }
        let input_path = imageoptions[index + 1]
        url_hdr = URL(fileURLWithPath: input_path)
        index += 1
    case "-s":
        if pq_export || hlg_export{
            print("Error: Only one type of export can be specified.")
            exit(1)
        }
        sdr_export = true
    case "-p":
        if sdr_export || hlg_export {
            print("Error: Only one type of export can be specified.")
            exit(1)
        }
        pq_export = true
    case "-h":
        if sdr_export || pq_export{
            print("Error: Only one type of export can be specified.")
            exit(1)
        }
        hlg_export = true
    case "-d":
        guard index + 1 < imageoptions.count else {
            print("Error: The -d option requires a argument.")
            exit(1)
        }
        let bit_depth_argument = String(imageoptions[index + 1])
        if bit_depth_argument == "8"{
            index += 1
        } else { if bit_depth_argument == "10"{
            bit_depth = CIFormat.RGB10
            index += 1
        } else {
            print("Error: Bit depth must be either 8 or 10.")
            exit (1)
        }}
    case "-c":
        guard index + 1 < imageoptions.count else {
            print("Error: The -c option requires color space argument.")
            exit(1)
        }
        let color_space_argument = String(imageoptions[index + 1])
        let color_space_option = color_space_argument.lowercased()
        switch color_space_option {
            case "srgb","709","rec709","rec.709","bt709","bt,709","itu709":
                sdr_color_space = CGColorSpace.itur_709
                hdr_color_space = CGColorSpace.itur_709_PQ
                hlg_color_space = CGColorSpace.itur_709_HLG
            case "p3","dcip3","dci-p3","dci.p3","displayp3":
                sdr_color_space = CGColorSpace.displayP3
                hdr_color_space = CGColorSpace.displayP3_PQ
                hlg_color_space = CGColorSpace.displayP3_HLG
            case "rec2020","2020","rec.2020","bt2020","itu2020","2100","rec2100","rec.2100":
                sdr_color_space = CGColorSpace.itur_2020_sRGBGamma
                hdr_color_space = CGColorSpace.itur_2100_PQ
                hlg_color_space = CGColorSpace.itur_2100_HLG
            default:
                print("Error: The -c option requires color space argument. (srgb, p3, rec2020)")
                exit(1)
        }
        index += 1
    default:
        print("Warning: Unknown option: \(option)")
    }
    index += 1
}

// 设置输出文件路径
if let outputFile = outputFile {
    url_export_heic = URL(fileURLWithPath: outputFile)
}

// 检查是否提供了输入文件
guard let url_hdr = url_hdr, let url_export_heic = url_export_heic else {
    print("Error: Input file must be specified with -i option")
    exit(1)
}

let hdr_image = CIImage(contentsOf: url_hdr, options: [.expandToHDR: true])
let tonemapped_sdrimage = hdr_image?.applyingFilter("CIToneMapHeadroom", parameters: ["inputTargetHeadroom":1.0])
let export_options = NSDictionary(dictionary:[kCGImageDestinationLossyCompressionQuality:imagequality ?? 0.85, CIImageRepresentationOption.hdrImage:hdr_image!])

var sdr_color_space = CGColorSpace.displayP3
var hdr_color_space = CGColorSpace.displayP3_PQ
var hlg_color_space = CGColorSpace.displayP3_HLG

let image_color_space = hdr_image?.colorSpace?.name
if (image_color_space! as NSString).contains("709") {
    sdr_color_space = CGColorSpace.itur_709
    hdr_color_space = CGColorSpace.itur_709_PQ
    hlg_color_space = CGColorSpace.itur_709_HLG
}
if (image_color_space! as NSString).contains("sRGB") {
    sdr_color_space = CGColorSpace.itur_709
    hdr_color_space = CGColorSpace.itur_709_PQ
    hlg_color_space = CGColorSpace.itur_709_HLG
}
if (image_color_space! as NSString).contains("2100") {
    sdr_color_space = CGColorSpace.itur_2020_sRGBGamma
    hdr_color_space = CGColorSpace.itur_2100_PQ
    hlg_color_space = CGColorSpace.itur_2100_HLG
}
if (image_color_space! as NSString).contains("2020") {
    sdr_color_space = CGColorSpace.itur_2020_sRGBGamma
    hdr_color_space = CGColorSpace.itur_2100_PQ
    hlg_color_space = CGColorSpace.itur_2100_HLG
}

while sdr_export{
    let sdr_export_options = NSDictionary(dictionary:[kCGImageDestinationLossyCompressionQuality:imagequality ?? 0.85])
    try! ctx.writeHEIFRepresentation(of: tonemapped_sdrimage!,
                                     to: url_export_heic,
                                     format: bit_depth,
                                     colorSpace: CGColorSpace(name: sdr_color_space)!,
                                     options:sdr_export_options as! [CIImageRepresentationOption : Any])
    exit(0)
}

while hlg_export{
    let hlg_export_options = NSDictionary(dictionary:[kCGImageDestinationLossyCompressionQuality:imagequality ?? 0.85])
    try! ctx.writeHEIFRepresentation(of: hdr_image!,
                                     to: url_export_heic,
                                     format: bit_depth,
                                     colorSpace: CGColorSpace(name: hlg_color_space)!,
                                     options:hlg_export_options as! [CIImageRepresentationOption : Any])
    exit(0)
}

while pq_export {
    let pq_export_options = NSDictionary(dictionary:[kCGImageDestinationLossyCompressionQuality:imagequality ?? 0.85])
    try! ctx.writeHEIF10Representation(of: hdr_image!,
                                       to: url_export_heic,
                                       colorSpace: CGColorSpace(name: hdr_color_space)!,
                                       options:pq_export_options as! [CIImageRepresentationOption : Any])
    exit(0)
}

try! ctx.writeHEIFRepresentation(of: tonemapped_sdrimage!,
                                 to: url_export_heic,
                                 format: bit_depth,
                                 colorSpace: CGColorSpace(name: sdr_color_space)!,
                                 options: export_options as! [CIImageRepresentationOption : Any])
exit(0)
