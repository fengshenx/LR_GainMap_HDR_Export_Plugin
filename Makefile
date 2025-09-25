all:
	mkdir -p ./export_heic.lrdevplugin
	# Compile the CoreImage metal shaders with the fcikernel flag
	xcrun -sdk macosx metal -fcikernel CustomFilter/GainMapKernel.ci.metal -o ./export_heic.lrdevplugin/GainMapKernel.ci.metallib
	# Compile the Swift code
	swiftc main.swift CustomFilter/*.swift -o ./export_heic.lrdevplugin/toGainMapHDR
