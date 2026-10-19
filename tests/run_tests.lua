-- Runs the QuickApp sources against a mocked HC3 runtime.
-- Usage: lua tests/run_tests.lua [src-dir]   (needs the dkjson rock)
local dk = require("dkjson")
local SRC = arg[1] or "src"

local fails = 0
local function check(cond, msg)
    if cond then print("ok:   " .. msg) else fails = fails + 1; print("FAIL: " .. msg) end
end

-- Mocked HC3 runtime -------------------------------------------------------
local devices = {
    { id = 1, name = "Root", parentId = 0, baseType = "com.fibaro.device", type = "com.fibaro.zwaveDevice",
      enabled = true, visible = false, interfaces = {"zwave"}, properties = {}, actions = {} },
    { id = 226, name = "Dimmer", parentId = 1, baseType = "com.fibaro.multilevelSwitch", type = "com.fibaro.FGD212",
      enabled = true, visible = true, interfaces = {"light", "zwave", "zwaveCentralScene"},
      properties = { value = 40, dead = false,
          centralSceneSupport = {
              { keyId = 1, keyAttributes = {"Pressed", "Released", "HeldDown", "Pressed2", "Pressed3"} },
              { keyId = 2.0, keyAttributes = {"Pressed", "Pressed2"} } } },
      actions = { turnOn = 0, turnOff = 0, setValue = 1 } },
    { id = 300, name = "KeyFob", parentId = 0, baseType = "com.fibaro.remoteController", type = "com.fibaro.FGKF601",
      enabled = true, visible = true, interfaces = {"zwave", "battery"},
      properties = { dead = false, batteryLevel = 90,
          centralSceneSupport = { { keyId = 1, keyAttributes = {"Pressed"} } } },
      actions = {} },
}

json = { encode = function(t) return dk.encode(t) end, decode = function(s) return dk.decode(s) end }
unpack = table.unpack
plugin = { mainDeviceId = 999 }
api = {
    get = function(path)
        if path == "/devices" then return devices end
        if path:find("network") then return { networkConfig = { eth0 = { enabled = true, ipConfig = { ip = "10.0.0.2" } } } } end
        local id = tonumber(path:match("/devices/(%d+)"))
        for _, d in ipairs(devices) do if d.id == id then return d end end
    end,
    post = function()
        local out = {}
        for _, d in ipairs(devices) do if d.visible then out[#out + 1] = { id = d.id } end end
        return out
    end,
}
fibaro = {
    getRoomNameByDeviceID = function() return "Living room" end,
    getGlobalVariable = function() return nil end,
    setTimeout = function() end,
    call = function() end,
}
net = { HTTPClient = function() return { request = function() end } end }
mqtt = { Client = { connect = function() return { addEventListener = function() end } end } }
QuickApp = {}

for _, f in ipairs({"tools", "device_api", "device_helper", "mqtt_convention_api", "main"}) do
    dofile(SRC .. "/" .. f .. ".lua")
end

local function newQuickApp(variables, warnings)
    local qa = setmetatable({ properties = { quickAppVariables = {} } }, { __index = QuickApp })
    local noop = function() end
    qa.debug, qa.trace, qa.error = noop, noop, noop
    qa.warning = function(_, msg) if warnings then warnings[#warnings + 1] = msg end end
    qa.updateView, qa.updateProperty = noop, noop
    qa.getVariable = function(_, name) return variables[name] or "" end
    return qa
end

-- Central scene: S1/S2 and remote buttons as HA device triggers -----------
local published = {}
local qa = newQuickApp({ mqttConvention = "home-assistant" })
qa.mqtt = { publish = function(_, topic, payload, opts)
    published[#published + 1] = { topic = topic, payload = payload, retain = opts and opts.retain }
end }
qa.mqttConventions = { clone(MqttConventionHomeAssistant) }
qa.mqttConventions[1].mqtt = qa.mqtt
qa:publishDeviceNodeToMqtt(qa:discoverDeviceHierarchy())

local triggers = {}
for _, m in ipairs(published) do
    if m.topic:match("^homeassistant/device_automation/.+/config$") then
        triggers[#triggers + 1] = dk.decode(m.payload)
    end
end
check(#triggers == 8, "8 device triggers discovered (7 dimmer, 1 remote), got " .. #triggers)
for _, t in ipairs(triggers) do
    if not (t.device and t.device.identifiers) then check(false, "trigger " .. tostring(t.payload) .. " has device info") end
end

-- Simulates HA: a trigger fires when {{ value_json.trigger }} equals its payload
local function press(id, keyId, attr)
    local before = #published
    qa:dispatchFibaroEventToMqtt({ type = "CentralSceneEvent", data = { id = id, keyId = keyId, keyAttribute = attr } })
    local fired, msgs = {}, {}
    for i = before + 1, #published do
        local m = published[i]
        msgs[#msgs + 1] = m
        for _, t in ipairs(triggers) do
            local v = (t.topic == m.topic) and dk.decode(m.payload)
            if v and v.trigger == t.payload then fired[#fired + 1] = t.subtype .. "/" .. t.type end
        end
    end
    return fired, msgs
end

local fired, msgs = press(226, 1, "Pressed")
check(#fired == 1 and fired[1] == "button_1/button_short_press", "S1 short press fires button_1/button_short_press")
local touched = false
for _, m in ipairs(msgs) do if m.topic:match("light/226/.*/value$") then touched = true end end
check(not touched, "S1 press does not overwrite the dimmer brightness")
check(msgs[1] ~= nil and msgs[1].retain == false, "scene event is published non-retained")

fired = press(226, 2, "Pressed2")
check(#fired == 1 and fired[1] == "button_2/button_double_press", "S2 double press fires button_2/button_double_press (keyId 2.0 in metadata)")

fired = press(226, 1, "HeldDown")
check(#fired == 1 and fired[1] == "button_1/button_long_press", "S1 hold fires button_1/button_long_press")

fired, msgs = press(300, 1, "Pressed")
check(#fired == 1, "remote button press fires its trigger")
local sensorUpdated = false
for _, m in ipairs(msgs) do
    if m.topic:match("sensor/300/.*/value$") and m.payload:find("1%-button_short_press") then sensorUpdated = true end
end
check(sensorUpdated, "remote sensor shows the last key press")

fired = press(1, 1, "Pressed")
check(#fired == 0, "events from excluded (hidden) devices are ignored")

-- MQTT convention selection -------------------------------------------------
for _, case in ipairs({
    { value = "", expected = "Home Assistant" },
    { value = "home-assistant", expected = "Home Assistant" },
    { value = "typo", expected = "Home Assistant", warns = true },
    { value = "homie,home-assistant", expected = "Homie,Home Assistant" },
}) do
    local warnings = {}
    local q = newQuickApp({ mqttConvention = case.value, mqttUrl = "mqtt://broker" }, warnings)
    local ok, err = pcall(q.establishMqttConnection, q)
    local names = {}
    for _, c in ipairs(q.mqttConventions or {}) do names[#names + 1] = c.type end
    check(ok and table.concat(names, ",") == case.expected,
        string.format("mqttConvention=%q connects with %s%s", case.value, case.expected, ok and "" or (" (" .. tostring(err) .. ")")))
    if case.warns then check(#warnings > 0, "unknown mqttConvention is logged") end
end

print(fails == 0 and "ALL TESTS PASSED" or (fails .. " TEST(S) FAILED"))
os.exit(fails == 0 and 0 or 1)
