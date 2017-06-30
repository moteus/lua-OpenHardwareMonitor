package.path = "..\\src\\?.lua;" .. package.path

-- Print hardware monitor tree

local ohm = require "OpenHardwareMonitor"

local function printf(...)
  print(string.format(...))
end

local function print_tree(t, indent)
  indent = indent or ""
  for _, node in ipairs(t) do
    printf("%s%s - %s (%s)", indent, node.type, node.name, node.identifier)
    if node.child then
      if node.child[1] then
        print_tree(node.child, indent..'  ')
      else
        for name, sensors in pairs(node.child) do
          printf("%s  %s", indent, name)
          for _, sensor in ipairs(sensors) do
            printf("%s    %s (%s) = %0.2f", indent, sensor.name, sensor.identifier, sensor.value)
          end
        end
      end
    end
  end
end

local monitor = ohm.new():open()

local tree = monitor:buildTree()

print_tree(tree)
