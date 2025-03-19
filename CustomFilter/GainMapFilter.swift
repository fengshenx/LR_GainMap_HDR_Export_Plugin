//
//  GainMapFilter.swift
//  toGainMapHDR
//
//  Created by Luyao Peng on 11/27/24.
//

import CoreImage

class GainMapFilter: CIFilter {
    var HDRImage: CIImage?
    var SDRImage: CIImage?
    var hdrmax: Float?
    static var kernel: CIKernel = { () -> CIColorKernel in
        // Find the executable path
        let executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        let executableDir = executableURL.deletingLastPathComponent()
        
        // Look for the metallib file in the same directory as the executable
        let metalLibURL = executableDir.appendingPathComponent("GainMapKernel.ci.metallib")
        
        print("Looking for metallib at: \(metalLibURL.path)")
        
        guard FileManager.default.fileExists(atPath: metalLibURL.path) else {
            fatalError("Metallib file does not exist at path: \(metalLibURL.path)")
        }
        
        do {
            let data = try Data(contentsOf: metalLibURL)
            do {
                let kernel = try CIColorKernel(
                    functionName: "GainMapFilter",
                    fromMetalLibraryData: data)
                return kernel
            } catch {
                fatalError("Failed to create color kernel: \(error)")
            }
        } catch {
            fatalError("Failed to load metallib data: \(error)")
        }
    }()
    override var outputImage: CIImage? {
        guard let HDRImage = HDRImage else { return nil }
        guard let SDRImage = SDRImage else { return nil }
        guard let hdrmax = hdrmax else { return nil }
        return GainMapFilter.kernel.apply(extent: HDRImage.extent,
                                          roiCallback: { _, rect in return rect},
                                          arguments: [HDRImage,SDRImage,hdrmax])
      }
}
