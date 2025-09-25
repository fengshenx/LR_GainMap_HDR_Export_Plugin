
# Usage:
#   make SIGN_ID="Developer ID Application: Your Name (TEAMID)"

PLUGIN_DIR=./export_heic.lrdevplugin
BUILD_DIR=./build
BIN_NAME=toGainMapHDR
BIN_UNI=$(PLUGIN_DIR)/$(BIN_NAME)
BIN_X86=$(BUILD_DIR)/$(BIN_NAME)_x86_64
BIN_ARM=$(BUILD_DIR)/$(BIN_NAME)_arm64
DMG_PATH=./export_heic.lrdevplugin.dmg
DMG_VOLNAME=GainMap HDR HEIF Exporter
LR_MODULES_DIR=$(HOME)/Library/Application\ Support/Adobe/Lightroom/Modules
DMG_STAGING=./dmg_root
BACKGROUND_PNG=./dmg_background.png

# Notarization configuration (choose ONE method)
# 1) Keychain profile (recommended):
#    NOTARY_PROFILE=YourNotarytoolProfileName
# or
# 2) Direct credentials:
#    APPLE_ID=you@appleid.com
#    TEAM_ID=TEAMID
#    APP_PASSWORD=app-specific-password
NOTARY_PROFILE?=
APPLE_ID?=
TEAM_ID?=
APP_PASSWORD?=

# Optional: set SIGN_ID to your Developer ID Application certificate
# Example: SIGN_ID=Developer ID Application: Your Name (TEAMID)
SIGN_ID?=

ifeq ($(strip $(SIGN_ID)),)
SIGN_CMD=@echo "Skipping codesign: SIGN_ID not set"
else
# Use Apple's timestamp server explicitly to avoid 'timestamp expected' errors
SIGN_CMD=codesign --force --options runtime --timestamp=http://timestamp.apple.com/ts01 --sign "$(SIGN_ID)" --verbose=4
endif

.PHONY: all clean

all:
	mkdir -p $(PLUGIN_DIR) $(BUILD_DIR)
	# Compile the CoreImage metal shaders with the fcikernel flag
	xcrun -sdk macosx metal -fcikernel CustomFilter/GainMapKernel.ci.metal -o $(PLUGIN_DIR)/GainMapKernel.ci.metallib
	# Compile Swift for x86_64
	swiftc -O -target x86_64-apple-macos15 \
		main.swift CustomFilter/*.swift -o $(BIN_X86)
	# Compile Swift for arm64
	swiftc -O -target arm64-apple-macos15 \
		main.swift CustomFilter/*.swift -o $(BIN_ARM)
	# Create universal binary
	lipo -create -output $(BIN_UNI) $(BIN_X86) $(BIN_ARM)
	chmod +x $(BIN_UNI)
	# Codesign executable (if SIGN_ID provided)
	$(SIGN_CMD) $(BIN_UNI)
	# Note: .lrdevplugin is not an app bundle; skip signing the directory itself

.PHONY: dmg dist adhoc install unquarantine notarize staple verify release help


dmg: all
	@echo "Preparing DMG staging at $(DMG_STAGING)"
	rm -rf "$(DMG_STAGING)" "$(DMG_PATH)"
	mkdir -p "$(DMG_STAGING)"
	# Copy plugin into staging
	cp -R "$(PLUGIN_DIR)" "$(DMG_STAGING)/export_heic.lrdevplugin"
	# Single-user install: user drags plugin into ~/Library/.../Modules manually
	# Optional background image support
	@if [ -f "$(BACKGROUND_PNG)" ]; then \
	  mkdir -p "$(DMG_STAGING)/.background"; \
	  cp "$(BACKGROUND_PNG)" "$(DMG_STAGING)/.background/background.png"; \
	fi
	@echo "Creating DMG: $(DMG_PATH)"
	hdiutil create -volname "$(DMG_VOLNAME)" -srcfolder "$(DMG_STAGING)" -ov -format UDZO "$(DMG_PATH)"

dist: dmg
	@echo "Built universal binary and packaged DMG at $(DMG_PATH)"

adhoc:
	$(MAKE) SIGN_ID=- all
	$(MAKE) zip

install: all
	mkdir -p "$(LR_MODULES_DIR)"
	rsync -a --delete "$(PLUGIN_DIR)/" "$(LR_MODULES_DIR)/export_heic.lrdevplugin/"
	@echo "Installed to $(LR_MODULES_DIR)/export_heic.lrdevplugin"

unquarantine:
	@echo "Removing quarantine attribute from $(PLUGIN_DIR)"
	xattr -dr com.apple.quarantine "$(PLUGIN_DIR)" || true

# Build NOTARY_SUBMIT command depending on provided credentials (DMG notarization)
ifeq ($(strip $(NOTARY_PROFILE)),)
  ifeq ($(and $(strip $(APPLE_ID)),$(strip $(TEAM_ID)),$(strip $(APP_PASSWORD))),)
NOTARY_SUBMIT=@echo "Skipping notarization: provide NOTARY_PROFILE or APPLE_ID/TEAM_ID/APP_PASSWORD"
  else
NOTARY_SUBMIT=xcrun notarytool submit "$(DMG_PATH)" --apple-id "$(APPLE_ID)" --team-id "$(TEAM_ID)" --password "$(APP_PASSWORD)" --wait
  endif
else
NOTARY_SUBMIT=xcrun notarytool submit "$(DMG_PATH)" --keychain-profile "$(NOTARY_PROFILE)" --wait
endif

notarize: dmg
	$(NOTARY_SUBMIT)

staple: notarize
	# Staple the DMG so it carries the notarization ticket offline
	xcrun stapler staple "$(DMG_PATH)"

verify:
	codesign --verify --strict --verbose=2 "$(BIN_UNI)" || true
	# Assess the distributable DMG for Gatekeeper open policy
	@if [ -f "$(DMG_PATH)" ]; then spctl --assess --type open -vv "$(DMG_PATH)" || true; else echo "(skip) $(DMG_PATH) not found"; fi
	# Assess the executable for Gatekeeper execute policy
	spctl --assess --type execute -vv "$(BIN_UNI)" || true

release: dist notarize staple
	@echo "Release is notarized and stapled: $(DMG_PATH)"

help:
	@echo "Targets:"
	@echo "  all            Build universal binary (arm64+x86_64) and optional sign"
	@echo "  dmg            Create distributable DMG ($(DMG_PATH))"
	@echo "  dist           Build + dmg"
	@echo "  adhoc          Build with ad-hoc signature and zip"
	@echo "  install        Copy plugin to Lightroom Modules dir"
	@echo "  unquarantine   Remove macOS quarantine attribute from plugin dir"
	@echo "  notarize       Submit DMG to Apple notarization (requires NOTARY_PROFILE or credentials)"
	@echo "  staple         Staple notarization ticket to DMG (after notarize)"
	@echo "  verify         Verify codesign and Gatekeeper assessment"
	@echo "  release        dist + notarize + staple"
	@echo "Variables: SIGN_ID=\"Developer ID Application: Your Name (TEAMID)\" (use '-' for ad-hoc)"

clean:
	rm -rf $(BUILD_DIR)
	rm -f $(PLUGIN_DIR)/GainMapKernel.ci.metallib $(BIN_UNI)
