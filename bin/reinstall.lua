local shell = require("shell")
local util = require("util")

shell.writeLine("Load internet...")
local internet = computer.getPCIDevices(classes.FINInternetCard)[1]
if not internet then
    shell.writeLine("ERROR! No internet-card found!")
    computer.beep(0.2)
    return
end

local user, repo, branch = "Panakotta00", "FicsIt-OS", "main"

local args = {...}
if #args > 1 then
    user = args[1]
    repo = args[2]
    branch = args[3] or "main"
end

local rurl = string.format(
    "https://raw.githubusercontent.com/%s/%s/%s/misc/install.lua",
    user, repo, branch
)
local ec, ed = internet:request(rurl, "GET", ""):await()
if ec ~= 200 or not ed then
    shell.writeLine("ERROR! Could not fetch install script")
    computer.beep(0.2)
    return
end

shell.writeLine("Close window within 10 seconds before beeps!")
for i = 0, 10 do
    util.sleep(1000)
    shell.writeLine(i .. "...")
    computer.beep(0.7)
end

shell.writeLine("Installing EEPROM BIOS...")
computer.setEEPROM(ed)
computer.reset()
