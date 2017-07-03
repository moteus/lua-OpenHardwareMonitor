package.path = "..\\src\\?.lua;" .. package.path

-- Print hardware monitor tree

local ohm = require "OpenHardwareMonitor"

local sensor_type_units = {
  Clock       = {"MHz",  "Megahertz"              };
  Control     = {"%",    "Percentage"             };
  Data        = {"GB",   "Gigabyte"               };
  Fan         = {"RPM",  "Revolutions per minute" };
  Flow        = {"L/h",  "Liters per hour"        };
  Level       = {"%",    "Percentage"             };
  Load        = {"%",    "Percentage"             };
  Power       = {"W",    "Wat"                    };
  Temperature = {"C",    "Celsius"                };
  Voltage     = {"V",    "Volt"                   };
}

local function printf(...)
  print(string.format(...))
end

local function print_tree(t, indent)
  indent = indent or ""
  for _, node in ipairs(t) do
    printf("%s%s - %s (%s)", indent, node.type, node.name, node.identifier)
    if node.child then
      print_tree(node.child, indent..'  ')
    end
    if node.sensors then
      for sensor_type, sensors in pairs(node.sensors) do
        printf("%s  %s", indent, sensor_type)
        local unit = sensor_type_units[sensor_type]
        unit = unit and unit[1] or ""
        if unit ~= '%' then unit = ' ' .. unit end
        for _, sensor in ipairs(sensors) do
          printf("%s    %s (%s) = %0.2f%s", indent, sensor.name, sensor.identifier, sensor.value, unit)
        end
      end
    end
  end
end

local monitor = ohm.new():open()

local tree = monitor:buildTree()

print_tree(tree)
