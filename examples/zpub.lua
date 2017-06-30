package.path = "..\\src\\?.lua;" .. package.path

-- Publish hardware minitoring info via ZeroMQ publisher

local ohm    = require "OpenHardwareMonitor"
local zmq    = require "lzmq"
local ztimer = require "lzmq.timer"
local json   = require "cjson"

local ctx = zmq.context()
local pub = ctx:socket{'PUB', bind = 'tcp://127.0.0.1:5588'}
local mon = ohm.new():open()

local filters = {
  {'/intelcpu/0', 'Temperature'};
  {'/intelcpu/0', 'Voltage'};
}

while true do
  local result = mon:select(filters)
  local msg    = json.encode(result)
  pub:send(msg)
  ztimer.sleep(5000)
end
