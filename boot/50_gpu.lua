local gpu = computer.getPCIDevices(classes.GPU_T1_C)[1]
local screen = computer.getPCIDevices(classes.FINComputerScreen)[1]

gpu:bindScreen(screen)
event.listen(gpu)
