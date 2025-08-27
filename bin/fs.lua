-- Mount and Unmount Disks by Partial UUID
local shell = require("shell")
local filesystem = require("filesystem")
local process = require("process")

-- Function to list all drives
local function listDrives()
    local drives = {}
    for _, drive in pairs(filesystem.children("/dev")) do
        table.insert(drives, drive)
    end
    return drives
end

-- Function to mount a drive by partial UUID
local function mountDrive(partialUUID)
    local drives = listDrives()
    for _, drive in ipairs(drives) do
        if drive:sub(1, #partialUUID) == partialUUID then
            local mountPoint = "/" .. drive
            if filesystem.mount("/dev/" .. drive, mountPoint) then
                shell.writeLine("Mounted " .. drive .. " to " .. mountPoint)
                return
            else
                shell.writeLine("Failed to mount " .. drive)
                return
            end
        end
    end
    shell.writeLine("No drive found with partial UUID: " .. partialUUID)
end

-- Function to unmount a drive by partial UUID
local function unmountDrive(partialUUID)
    local drives = listDrives()
    for _, drive in ipairs(drives) do
        if drive:sub(1, #partialUUID) == partialUUID then
            local mountPoint = "/" .. drive
            if filesystem.unmount(mountPoint) then
                shell.writeLine("Unmounted " .. drive .. " from " .. mountPoint)
                return
            else
                shell.writeLine("Failed to unmount " .. drive)
                return
            end
        end
    end
    shell.writeLine("No drive found with partial UUID: " .. partialUUID)
end

-- CLI Handler
local args = {...}
local sub = args[1]
table.remove(args, 1)

if sub == "mount" then
    local partialUUID = args[1]
    if not partialUUID then
        shell.writeLine("No partial UUID provided for mounting!")
        return 1
    end
    mountDrive(partialUUID)
elseif sub == "unmount" then
    local partialUUID = args[1]
    if not partialUUID then
        shell.writeLine("No partial UUID provided for unmounting!")
        return 1
    end
    unmountDrive(partialUUID)
else
    shell.writeLine("Usage:")
    shell.writeLine("fs mount <partial-uuid>  - Mount a drive by partial UUID")
    shell.writeLine("fs unmount <partial-uuid> - Unmount a drive by partial UUID")
end
