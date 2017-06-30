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

local function is_sensors_array(t)
  return not t[1]
end

local function find_tree(t, fn)
  for _, node in ipairs(t) do
    if node.child then
      local item = find_tree(node.child, fn)
      if item then return item end
    end
    if fn(node) then return node end
  end
end

local function order_by_index(t)
  for _, node in ipairs(t) do
    if node.child then
      if is_sensors_array(node.child) then
        for stype, sensors in pairs(node.child) do
          table.sort(sensors, function(lhs, rhs)
            return lhs.index < rhs.index
          end)
        end
      else
        order_by_index(node.child)
      end
    end
  end
  return t
end

local function tree_select_sensors(t, name, ...)
  if not name then return t end

  if is_sensors_array(t) then
    local sensors = t[name]
    if sensors then 
      return tree_select_sensors(sensors, ...)
    end
    return
  end

  for _, node in ipairs(t) do
    if node.name == name then
      if node.child then
        return tree_select_sensors(node.child, ...)
      end
      if ... then return nil end
      return node
    end
  end
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
  end

  for _ = 1, #sensors do
    for i = #sensors, 1, -1 do
      local s = sensors[i]
      local node = find_tree(tree, function(node)
        return node.identifier == s.parent
      end)
      if node then
        if not node.child then node.child = {} end
        table.remove(sensors, i)
        local stype = s.type
        if not node.child[stype] then node.child[stype] = {} end
        append(node.child[stype], s)
      end
    end
  end

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
