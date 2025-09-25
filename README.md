# Gainmap HDR HEIF Export Plugin for Lightroom Classic

This plugin enables exporting in the Gainmap HDR HEIF format from Lightroom Classic.

Starting with LRC 14.0, HDR export is supported, but it doesn’t include Gainmap support, which causes compatibility issues on Android devices. This plugin resolves that problem.

**Note**: Currently supports Lightroom Classic 14.0 and macOS 15.0 only.

Gainmap code is from [PQ_HDR_to_Gain_Map_HDR](https://github.com/chemharuka/PQ_HDR_to_Gain_Map_HDR)

---
## Download the LRC plugin

1. Download the plugin. [Release](https://github.com/fengshenx/LR_GainMap_HDR_Export_Plugin/releases/tag/v1.1)
2. Open the DMG file.
3. Drag the export_heic.lrdevplugin to your disk.


## Adding the Plugin to LRC

1. Open the "Plug-in Manager" in LRC.
2. Click "Add."
3. Select this plugin.

---

## How to Use

1. Select your photo(s) and open the Export window.
2. At the top, choose "Export to HEIC."
3. Set the export format to **TIFF**.
4. Enable HDR output, but **disable "Maximum Compatibility"**
5. Start the export process.

---

## Build

1. Install the Xcode development environment.
2. Run `make` in the directory.

Since the export process uses TIFF as an intermediary format, ensure you select **TIFF** for export.

-------------

# Gainmap HDR Heif Lightroom Classic导出插件
这是一个支持Gainmap HDR Heif格式导出的Lightroom Classic插件。

LRC 14.0开始支持HDR导出了，但是导出格式不支持Gainmap，在Android手机上有兼容问题。这个插件可以解决这个问题。

注意：当前仅支持Lightroom Classic 14.0 和 MacOS 15.0

Gainmap算法来自：[PQ_HDR_to_Gain_Map_HDR](https://github.com/chemharuka/PQ_HDR_to_Gain_Map_HDR)

## 下载插件

1. 下载插件。 [点我下载](https://github.com/fengshenx/LR_GainMap_HDR_Export_Plugin/releases/tag/v1.0)
2. 解压文件。
  
## LRC中添加插件
* 打开LRC的增效工具管理器
* 点击 **添加**
* 选择这个插件

## 使用方法
* 选择照片，并打开导出窗口
* 在顶部选择 "Export to HEIC"
* 选择导出格式为**TIFF**。
* 选择HDR输出。同时**不要选择最大兼容性**。
* 开始导出

## 编译
* 安装Xcode开发环境，在目录下执行`make`

因为导出使用TIFF格式为中间格式，请务必选择导出为**TIFF**格式。 
