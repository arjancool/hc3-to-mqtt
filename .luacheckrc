-- luacheck configuration for the Fibaro QuickApp
-- All src/*.lua files are loaded into the same QuickApp runtime so cross-file
-- globals are intentional. We declare them here so luacheck doesn't flag them.

std = "lua53"
max_line_length = false
codes = true

-- Globals provided by the Fibaro HC3 runtime
read_globals = {
    "fibaro",
    "json",
    "mqtt",
    "api",
    "net",
    "plugin",
    "QuickApp",
    "MqttConventionPrototype", -- prototype declared in mqtt_convention_api
    "developmentMode",
}

-- Symbols defined in one src/ file and referenced in another. luacheck would
-- otherwise complain about "non-standard global variable" everywhere.
globals = {
    -- prototypes / classes (device_api.lua)
    "PrototypeEntity",
    "Switch", "Light", "Dimmer", "Rgbw",
    "GenericSensor", "BinarySensor", "MultilevelSensor",
    "Cover", "Thermostat",
    "RemoteController", "RemoteControllerKey",
    "haEntityTypeMappings",

    -- mqtt conventions (mqtt_convention_api.lua)
    "MqttConventionHomeAssistant",
    "MqttConventionHomie",
    "MqttConventionDebug",
    "mqttConventionMappings",
    "localIpAddress",

    -- device hierarchy / counters (device_helper.lua)
    "deviceHierarchyRootNode",
    "deviceNodeById",
    "deviceFilter",
    "fibaroDevices",
    "allFibaroDevicesAmount",
    "filteredFibaroDevicesAmount",
    "identifiedHaEntitiesAmount",
    "__logger",

    -- helpers (tools.lua / device_helper.lua)
    "transliterate", "extractMetaInfoFromDeviceName",
    "splitString", "splitStringToNumbers",
    "table_contains_value",
    "isEmptyString", "isNotEmptyString",
    "base64Encode", "base64Decode", "decodeBase64Auth",
    "shallowInsertTo", "shallowCopyTo",
    "clone", "inheritFrom",
    "isNumber", "round",
    "identifyLocalIpAddressForHc3",
    "getCompositeQuickAppVariable",
    "logWithoutRepetableWarnings",
    "sanitizeMqttUrl",
    "cleanDeviceCache",
    "getDeviceHierarchyByFilter",
    "appendNodeByFibaroDevice",
    "createUnidentifiedDeviceNode",
    "getDeviceNodeById",
    "removeDeviceNodeFromHierarchyById",
    "createAndAddDeviceNodeToHierarchyById",
    "enrichFibaroDeviceWithMetaInfo",
    "fibaroDeviceTypeContains", "fibaroDeviceTypeMatchesWith",
    "fibaroDeviceHasInterface", "fibaroDeviceHasAction", "fibaroDeviceHasProperty",
    "createLinkedMultilevelSensorDevice", "createLinkedKey", "createLinkedFibaroDevice",
    "getDeviceDescriptionById",
    "printDeviceNodeHierarchy",
    "createFibaroEventPayload",
}

-- Allow `unpack` (Lua 5.1) and `table.unpack` (Lua 5.3+) since Fibaro Lua mixes versions
files["src/device_api.lua"].read_globals = { "unpack" }

-- Suppress purely cosmetic warnings that span the whole codebase
ignore = {
    "611",  -- line contains only whitespace
    "612",  -- line contains trailing whitespace
    "613",  -- trailing whitespace in a string
    "614",  -- trailing whitespace in a comment
    "621",  -- inconsistent indentation (tabs/spaces)
    "631",  -- line is too long
}
