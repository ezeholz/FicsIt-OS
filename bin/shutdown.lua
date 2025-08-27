-- Shutdown and Reboot Computer
local shell = require("shell")

-- CLI Handler
local args = {...}

--[[
for i, arg in ipairs(args) do
  if arg == "-t" then
    future.sleep(tonumber(args[i + 1]) or 0)
    break
  end
end
]]--

for _, arg in ipairs(args) do
  if arg == "-r" then
    computer.reset()
  elseif arg == "-s" then
    computer.stop()
  end
end

shell.writeLine("Usage:")
shell.writeLine("shutdown -s          Shutdown the computer")
shell.writeLine("shutdown -r          Reboot the computer")
--shell.writeLine("shutdown -t <time>  Schedule a shutdown after <time> seconds")