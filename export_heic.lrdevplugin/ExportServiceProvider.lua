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
}

exportServiceProvider.startDialog = function(propertyTable)
    local f = LrView.osFactory()
    local bind = LrView.bind
    local share = LrView.share

    -- Ensure imageQuality is an integer
    propertyTable:addObserver('imageQuality', function()
        propertyTable.imageQuality = math.floor(propertyTable.imageQuality + 0.5)
    end)

    local contents = f:column {
        bind_to_object = propertyTable,
        f:row {
            f:static_text {
                title = "Image Quality:",
                alignment = 'right',
                width = share 'label_width',
            },
            f:slider {
                value = bind 'imageQuality',
                min = 0,
                max = 100,
                width_in_chars = 20,
                fill_horizontal = 1,
            },
            f:edit_field {
                value = bind 'imageQuality',
                width_in_chars = 3,
            },
        },
    }

    return contents
end

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

    for i, rendition in exportSession:renditions() do
        progressScope:setPortionComplete(i-1, nPhotos)

        local success, pathOrMessage = rendition:waitForRender()
        if success then
            local heicPath = LrPathUtils.replaceExtension(pathOrMessage, "heic")
            local pluginPath = LrPathUtils.child(_PLUGIN.path, "ghdr")

            local command = string.format("%s -q %f -i %s %s", pluginPath, imageQuality/100, pathOrMessage, heicPath)
            -- local command = string.format("magick %s -sampling-factor 4:2:2 -quality %d %s", pathOrMessage,imageQuality, heicPath)

            local result = LrTasks.execute(command)
            if result ~= 0 then
                LrDialogs.showError("Failed to convert to HEIC.")
            else
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