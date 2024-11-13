# HEIC Exporter for Lightroom Classic
This is a Lightroom plugin that can change the output file to Heic format.

Although Lightroom currently supports Heic display, it does not support output in Heic format. This plug-in will solve this problem.

Note: Currently only Lightroom Classic and MacOS Sequoia are supported.

# Add to LR
* Open the Lightroom Classic Plugin Manager.
* Click “Add”.
* Select this plugin.

# Usage
* Select the photos you want to export
* Open the export dialog box and select "Export to HEIC" at the top.
* Set the export image format to TIFF.
* Select HDR output, Color Space HDR P3. Don't select maximize compatibility
* Start export

# Build
* Install Xcode development tools and make

Because this plug-in first exports to an TIFF format and then converts it to HEIC, Make sure to select TIFF as the export format.

