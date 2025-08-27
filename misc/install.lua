computer.beep(5.0)
print("Load internet...")
local internet = computer.getPCIDevices(classes.FINInternetCard)[1]
if not internet then
    print("ERROR! No internet-card found!")
    computer.beep(0.2)
    return
end

local user, repo, branch = "Panakotta00", "FicsIt-OS", "main"
print("Load filesystem...")
filesystem.initFileSystem("/dev")

-- Mount the first available drive (persisted storage)
local drive = ""
for _, f in pairs(filesystem.children("/dev")) do
    if f ~= "serial" then drive = f; break end
end
if drive == "" then
    print("ERROR! No drive found for install or temp storage!")
    computer.beep(0.2)
    return
end
filesystem.mount("/dev/" .. drive, "/")

-- Create a temp folder to store json.lua
filesystem.createDir("/tmp", true)

-- Download JSON library into /tmp/json.lua
print("Downloading JSON library...")
local req = internet:request(
    "https://raw.githubusercontent.com/rxi/json.lua/master/json.lua",
    "GET", ""
)
local _, libdata = req:await()
if not libdata then
    print("ERROR! Failed to get json.lua")
    computer.beep(0.2)
    return
end
local file = filesystem.open("/tmp/json.lua", "w")
file:write(libdata)
file:close()

-- Load JSON library
local json = filesystem.doFile("/tmp/json.lua")
if not json then
    print("ERROR! Could not load JSON library")
    computer.beep(0.2)
    return
end

-- Prepare clone requests
local requests = {}
local function requestFile(url, path)
    print("Downloading", path)
    local r = internet:request(url, "GET", "")
    table.insert(requests, {
        request = r,
        func = function(rq)
            local code, data = rq:await()
            if code ~= 200 or not data then
                print("ERROR! Failed to get", path)
                return false
            end
			if filesystem.exists(path) then filesystem.remove(path, true) end
            filesystem.createDir(path:sub(1, #path - #filesystem.path(3, path)), true)
            local f = filesystem.open(path, "w")
            f:write(data)
            f:close()
            return true
        end
    })
end

-- Cloning logic (similar to before)
local apiURL = string.format(
    "https://api.github.com/repos/%s/%s/git/trees/%s?recursive=1",
    user, repo, branch
)
print("Fetching repository tree...")
local c, body = internet:request(apiURL, "GET", ""):await()
if c ~= 200 or not body then
    print("ERROR! Could not fetch repo tree")
    computer.beep(0.2)
    return
end

local tree = json.decode(body)
for _, obj in ipairs(tree.tree or {}) do
    if obj.type == "blob" then
        local rawurl = string.format(
            "https://raw.githubusercontent.com/%s/%s/%s/%s",
            user, repo, branch, obj.path
        )
        local dest = "/" .. obj.path
        requestFile(rawurl, dest)
    end
end

-- Execute downloads
print("Downloading files...")
while #requests > 0 do
    local entry = table.remove(requests, 1)
    if not entry.func(entry.request) then
        computer.beep(0.2)
        return
    end
end

-- EEPROM BIOS installation (as before)
print("Request EEPROM BIOS...")
local eurl = string.format(
    "https://raw.githubusercontent.com/%s/%s/%s/misc/bootLoader.lua",
    user, repo, branch
)
local ec, ed = internet:request(eurl, "GET", ""):await()
if ec ~= 200 or not ed then
    print("ERROR! Could not fetch EEPROM BIOS")
    computer.beep(0.2)
    return
end

event.ignoreAll()
event.clear()
print("Close window within 10 seconds before beeps!")
for i = 0, 10 do
    event.pull(1)
    print(i .. "...")
    computer.beep(0.7)
end

print("Installing EEPROM BIOS...")
computer.setEEPROM(ed)
for i = 1, 4 do
    computer.beep(1.5)
    event.pull(0.2)
end

print("Installation Complete!")
