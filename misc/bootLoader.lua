event.ignoreAll()
event.clear()
 
filesystem.initFileSystem("/dev")
 
for i, f in pairs(filesystem.children("/dev")) do
	local driveLetter = string.char(string.byte("A") + i - 1)
	if not (f == "serial") then
		filesystem.mount("/dev/" .. f, "/tmp")
		if filesystem.exists("/tmp/boot/run.lua") then filesystem.mount("/dev/" .. f, "/") end
		filesystem.unmount("/tmp")
 		filesystem.mount("/dev/" .. f, "/dev/mnt/" .. driveLetter)
	end
end
if not filesystem.exists("/boot/run.lua") then
	print("ERROR! Failed to find filesystem! Please insert a drive or floppy with FicsIt-OS installed!")
	computer.beep(0.2)
	return
end
 
func = filesystem.loadFile("/boot/run.lua")

if func then
	computer.beep(5)
	func()
end