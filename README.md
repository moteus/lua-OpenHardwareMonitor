# lua-OpenHardwareMonitor
[![License](http://img.shields.io/badge/Licence-MIT-brightgreen.svg)](LICENSE)

Access to [OpenHardwareMonitor](https://github.com/openhardwaremonitor/openhardwaremonitor) WMI interface



# Usage
```Lua
local monitor = OpenHardwareMonitor.new()

-- Connect to OpenHardwareMonitor MWI source
monitor:open()

-- get all information as 2 arrays
local hardware, sensors = monitor:fetchAll()

-- get information as tree (similar as in GUI)
local tree = monitor:buildTree()

-- select specific sensors/hardware by names
local rs = monitor:select{
  {'/intelcpu/0', 'Temperature'};
  {'/intelcpu/0', 'Voltage'};
}

local Temperatures = rs[1]
if Temperatures then
  for _, v in ipairs(Temperatures) do
    print(v.name, v.value)
  end
end
```

