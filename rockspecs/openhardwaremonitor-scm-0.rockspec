package = "OpenHardwareMonitor"
version = "scm-0"
source = {
  url = "https://github.com/moteus/lua-OpenHardwareMonitor/archive/master.zip",
  dir = "lua-OpenHardwareMonitor-master",
}

description = {
  summary = "Access to OpenHardwareMonitor WMI interface",
  homepage = "https://github.com/moteus/lua-OpenHardwareMonitor",
  detailed = [[]],
  license  = "MIT/X11",
}

supported_platforms = {
  "windows"
}

dependencies = {
  "lua >= 5.1, < 5.4",
  "luacom",
}

build = {
  type = "builtin",
  copy_directories = {"examples"},

  modules = {
    [ "OpenHardwareMonitor" ] = "src/OpenHardwareMonitor.lua",
  }
}
