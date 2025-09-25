local LrTasks = import 'LrTasks'
local LrDialogs = import 'LrDialogs'
local LrPathUtils = import 'LrPathUtils'
local LrExportSession = import 'LrExportSession'
local LrFileUtils = import 'LrFileUtils'
local LrView = import 'LrView'
local LrBinding = import 'LrBinding'
local LrProgressScope = import 'LrProgressScope'

local exportServiceProvider = {}

exportServiceProvider.exportPresetFields = {
    { key = 'imageQuality', default = 70 },
    { key = 'conversionTool', default = 'toGainMapHDR' }, -- Added conversion tool option
}



exportServiceProvider.sectionsForTopOfDialog = function(viewFactory, propertyTable)
    local f = viewFactory

    -- Ensure imageQuality is an integer
    propertyTable:addObserver('imageQuality', function()
        propertyTable.imageQuality = math.floor(propertyTable.imageQuality + 0.5)
    end)

    return {
        {
            title = "HEIC Export Options",
            f:row {
                f:static_text {
                    title = "Image Quality:",
                    alignment = 'right',
                    width = LrView.share 'label_width',
                },
                f:slider {
                    value = LrView.bind 'imageQuality',
                    min = 0,
                    max = 100,
                    width_in_chars = 20,
                    fill_horizontal = 1,
                },
                f:edit_field {
                    value = LrView.bind 'imageQuality',
                    width_in_chars = 3,
                },
            },
            f:row {
                f:static_text {
                    title = "Conversion Tool:",
                    alignment = 'right',
                    width = LrView.share 'label_width',
                },
                f:popup_menu {
                    items = {
                        { title = 'Default', value = 'toGainMapHDR' },
                        { title = 'MacOS SIPS(Only HEIC)', value = 'sips' },
                    },
                    value = LrView.bind 'conversionTool',
                },
            },
        },
    }
end

exportServiceProvider.processRenderedPhotos = function(functionContext, exportContext)
    local exportSession = exportContext.exportSession
    local nPhotos = exportSession:countRenditions()
    local progressScope = LrProgressScope({
        title = 'Exporting to HEIC',
        functionContext = functionContext
    })

    local imageQuality = exportContext.propertyTable.imageQuality or 70
    local conversionTool = exportContext.propertyTable.conversionTool or 'toGainMapHDR'

    for i, rendition in exportSession:renditions() do
        progressScope:setPortionComplete(i-1, nPhotos)

        local success, pathOrMessage = rendition:waitForRender()
        if success then
            local heicPath = LrPathUtils.replaceExtension(pathOrMessage, "heic")

            local command
            if conversionTool == 'toGainMapHDR' then
                local pluginPath = LrPathUtils.child(_PLUGIN.path, "toGainMapHDR")
                local destFolder = LrPathUtils.parent(heicPath)
                command = string.format('"%s" "%s" "%s" -q %.2f -g', pluginPath, pathOrMessage, destFolder, imageQuality/100)

            elseif conversionTool == 'sips' then
                command = string.format('sips -s format heic -s formatOptions %s -o "%s" "%s"', imageQuality, heicPath, pathOrMessage)
            end

            -- Display the command in debug dialog
            -- LrDialogs.message("Command to execute", command)
            
            local result, output = LrTasks.execute(command, {captureStdout = true})
            if result ~= 0 then
                LrDialogs.showError("Failed to convert to HEIC. Error: " .. (output or "Unknown error"))
            else
                -- Display successful output for debugging
                -- LrDialogs.message("Command Successful", "Output: " .. (output or "No output"))
                LrFileUtils.delete(pathOrMessage)
            end
        else
            LrDialogs.showError("Error rendering photo: " .. tostring(pathOrMessage))
        end

        progressScope:setPortionComplete(i, nPhotos)
        if progressScope:isCanceled() then break end
    end
    progressScope:done()
end

return exportServiceProvider
