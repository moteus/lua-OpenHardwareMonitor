------------------------------------------------------------------
--
--  Author: Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Copyright (C) 2017 Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Licensed according to the included 'LICENSE' document
--
--  This file is part of lua-OpenHardwareMonitor library.
--
------------------------------------------------------------------
local _VERSION   = '0.1.0-dev'
local _COPYRIGHT = 'Copyright (C) 2017 Alexey Melnichuk'

local luacom = require "luacom"

local unpack = unpack or table.unpack

local function append(t, v) t[#t+1] = v return t end

local function find_tree(t, fn)
  for _, node in ipairs(t) do
    if node.child then
      local item = find_tree(node.child, fn)
      if item then return item end
    end
    if node.sensors then
      local item = find_tree(node.sensors, fn)
      if item then return item end
    end
    if fn(node) then return node end
  end
end

local function by_sensor_index(lhs, rhs)
  return lhs.index < rhs.index
end

local function by_hardware_type_and_identifier(lhs, rhs)
  if lhs.type == rhs.type then
    return lhs.identifier < rhs.identifier
  end
  return lhs.type < rhs.type
end

local function order_by_index(t)
  table.sort(t, by_hardware_type_and_identifier)
  for _, node in ipairs(t) do
    if node.sensors then
      for _, sensors in pairs(node.sensors) do
        table.sort(sensors, by_sensor_index)
      end
    end
    if node.child then
      order_by_index(node.child)
    end
  end
  return t
end

local function tree_select_sensors(t, name, ...)
  if not name then return t end

  if not t[1] then
    local sensors = t[name]
    return sensors and tree_select_sensors(sensors, ...)
  end

  for _, node in ipairs(t) do
    if node.name == name or node.identifier == name then
      if not ... then return node end
      if node.child then
        local item = tree_select_sensors(node.child, ...)
        if item then return item end
      end
      if node.sensors then
        local item = tree_select_sensors(node.sensors, ...)
        if item then return item end
      end
      if select('#', ...) == 1 then return node[...] end
      break
    end
  end
  return nil
end

local OpenHardwareMonitor = {} do
OpenHardwareMonitor.__index = OpenHardwareMonitor

function OpenHardwareMonitor.new()
  local self = setmetatable({}, OpenHardwareMonitor)

  return self
end

function OpenHardwareMonitor:open(computer, user, password)
  computer = computer or "."

  local connect_string = [[winmgmts:%s\\%s\root\OpenHardwareMonitor]]
  connect_string = string.format(connect_string, user and "" or "{impersonationLevel=Impersonate}!", computer)

  if user then
    self._wmi = luacom.GetObject(connect_string, user, password)
  else
    self._wmi = luacom.GetObject(connect_string)
  end

  if not self._wmi then
    return nil, "Failed to connect to computer "..computer
  end

  self._ref = luacom.CreateObject ("WbemScripting.SWbemRefresher")
  self._ref.AutoReconnect = 1
  self._hardware = self._ref:AddEnum(self._wmi, "Hardware").ObjectSet
  self._sensors  = self._ref:AddEnum(self._wmi, "Sensor").ObjectSet

  if not (self._hardware and self._sensors) then
    self:close()
    return nil, "Failed get info from OpenHardwareMonitor on computer "..computer
  end

  return self
end

function OpenHardwareMonitor:fetchAll()
  local hardware, sensors = {}, {}
  self._ref:Refresh()

  for _, item in luacom.pairs(self._hardware) do
    append(hardware, {
      name       = item:Name();
      type       = item:HardwareType();
      parent     = item:Parent();
      identifier = item:Identifier();
    })
  end

  for _, item in luacom.pairs(self._sensors) do
    append(sensors, {
      name       = item:Name();
      type       = item:SensorType();
      parent     = item:Parent();
      identifier = item:Identifier();
      value      = item:Value();
      min        = item:Min();
      max        = item:Max();
      index      = item:Index();
    })
  end

  return hardware, sensors
end

function OpenHardwareMonitor:buildTree()
  local hardware, sensors = self:fetchAll()
  local tree = {}

  -- use this for just in case to eliminate infinity loop
  -- in case of some unpredictiable results
  for _ = 1, #hardware do
    for i = #hardware, 1, -1 do
      local h = hardware[i]
      if h.parent == '' then
        table.remove(hardware, i)
        append(tree, h)
      else
        local node = find_tree(tree, function(node)
          return node.identifier == h.parent
        end)
        if node then
          if not node.child then node.child = {} end
          table.remove(hardware, i)
          append(node.child, h)
        end
      end
    end
    if #hardware == 0 then break end
  end

  assert(#hardware == 0)

  for i = #sensors, 1, -1 do
    local s = sensors[i]
    local node = find_tree(tree, function(node)
      return node.identifier == s.parent
    end)
    if node then
      if not node.sensors then node.sensors = {} end
      table.remove(sensors, i)
      local stype = s.type
      if not node.sensors[stype] then node.sensors[stype] = {} end
      append(node.sensors[stype], s)
    end
  end

  assert(#sensors == 0)

  return order_by_index(tree)
end

function OpenHardwareMonitor:select(paths)
  local tree = self:buildTree()
  local result = {}
  for i, path in ipairs(paths) do
    result[i] = tree_select_sensors(tree, unpack(path))
  end
  return result
end

function OpenHardwareMonitor:close()
  self._wmi, self._ref, self._hardware, self._sensors = nil
  collectgarbage() collectgarbage()
end

end

return {
  _NAME      = "OpenHardwareMonitor";
  _LICENSE   = "MIT";
  _VERSION   = _VERSION;
  _COPYRIGHT = _COPYRIGHT;

  new = OpenHardwareMonitor.new
}
