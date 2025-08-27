-- Shutdown and Reboot Computer
local shell = require("shell")
local util = require("util")

-- CLI Handler
local args = {...}
local sleepTime = 0
local action = nil

for i, arg in ipairs(args) do
  if arg == "-t" then
    sleepTime = tonumber(args[i + 1]) or 0
  elseif arg:sub(1, 1) == "-" and not action then
    action = arg
  elseif arg:sub(1, 1) == "-" then
    action = nil
    break
  end
end

if sleepTime and action then
  util.sleep(sleepTime * 1000)
end

if action == "-r" then
  computer.beep(0)
  computer.reset()
  return
elseif action == "-s" then
  computer.beep(0)
  computer.stop()
  return
end

shell.writeLine("Usage:")
shell.writeLine("-s          Shutdown the computer")
shell.writeLine("-r          Reboot the computer")
shell.writeLine("-t <time>  Schedule an action after <time> seconds")