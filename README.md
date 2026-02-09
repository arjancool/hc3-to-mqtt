# "Fibaro Home Center 3" to "Home Assistant" integration (Fork)

> **This is a fork of [alexander-vitishchenko/hc3-to-mqtt](https://github.com/alexander-vitishchenko/hc3-to-mqtt) v1.0.235**
> The original project bridges Fibaro HC3/HCL/Yubii Home devices to Home Assistant via MQTT.
> This fork adds a heartbeat/alive feature and improved sensor device_class mapping.

## 🔀 Fork changes (v1.0.235-fork-1)

### Heartbeat / Alive message
Publishes a periodic status message to MQTT so Home Assistant can monitor whether the HC3 bridge is alive and responsive.

- **Topic:** `homeassistant/hc3-heartbeat`
- **Interval:** configurable via QuickApp variable `heartbeatInterval` (default: 60 seconds)
- **Payload example:**
```json
{
    "status": "online",
    "timestamp": "2025-01-15T14:30:00Z",
    "uptime": 3600,
    "version": "1.0.235-fork-1",
    "devices": 42,
    "entities": 58,
    "ip": "192.168.1.100"
}
```

#### Configuring the heartbeat interval

The heartbeat interval can be configured via the QuickApp variable `heartbeatInterval` in your Fibaro HC3:

1. Open the QuickApp in your Fibaro HC3 web interface
2. Go to the **Variables** section
3. Add a new variable: name = `heartbeatInterval`, value = number of seconds (e.g. `30`, `60`, `120`)
4. Save and restart the QuickApp

If the variable is not set, the default interval of **60 seconds** is used. Lower values give faster detection of connection issues, but generate more MQTT traffic. A value of `30` is a good balance for most setups.

#### Home Assistant MQTT sensor configuration

```yaml
mqtt:
  sensor:
    - name: "HC3 Bridge Status"
      unique_id: hc3_bridge_status
      state_topic: "homeassistant/hc3-heartbeat"
      value_template: "{{ value_json.status }}"
      json_attributes_topic: "homeassistant/hc3-heartbeat"
      json_attributes_template: "{{ value_json | tojson }}"
      icon: "mdi:bridge"

    - name: "HC3 Bridge Uptime"
      unique_id: hc3_bridge_uptime
      state_topic: "homeassistant/hc3-heartbeat"
      value_template: "{{ value_json.uptime }}"
      unit_of_measurement: "s"
      device_class: "duration"
      icon: "mdi:timer-outline"

  binary_sensor:
    - name: "HC3 Bridge Online"
      unique_id: hc3_bridge_online
      state_topic: "homeassistant/hc3-status"
      payload_on: "online"
      payload_off: "offline"
      device_class: "connectivity"
      icon: "mdi:server-network"
```

### Improved sensor device_class mapping
Based on [Eroi69's fix](https://github.com/Eroi69/hc3-to-mqtt/commit/7bc34385f753d25f70728cb290ad9747cb31fe83). The original code determined `device_class` only from the Fibaro subtype, which missed common units. This fork maps the unit of measurement to the correct Home Assistant device_class:

| Unit | device_class | state_class |
|------|-------------|-------------|
| A | current | measurement |
| V | voltage | measurement |
| W | power | measurement |
| kWh | energy | total_increasing |
| Wh | energy | total_increasing |
| °C / °F | temperature | measurement |
| lx | illuminance | measurement |
| % | humidity | measurement |

Falls back to the original subtype-based logic for units not in this mapping.

---

## How to use

<ol>
    <li>
        Make sure you have MQTT broker installed, e.g. <a href="https://github.com/home-assistant/addons/blob/master/mosquitto/DOCS.md">Mosquitto within your Home Assistance instance</a>. 
        <br><br>
    </li>
    <li>
        Make sure you have "MQTT" integration added and configured your Home Assistant instance, as <a href="https://www.home-assistant.io/integrations/mqtt">described here</a>. 
        <br><br>
    </li>
    <li>
        Upload the Fibaro QuickApp (.fqa file) to your Fibaro Home Center 3 instance:
        <ul>
            <li>Open the Configuration Interface</li>
            <li>Go to Settings > Devices</li>
            <li>Click  +</li>
            <li>Choose Other Device</li>
            <li>Choose Upload File</li>
            <li>Choose file from your computer with .fqa</li>
        </ul>
        <br>
    </li>
    <li>
        Configure your Fibaro QuickApp:<br>
        <ul>
            <li> "<b>mqttUrl</b>" - URL for connecting to MQTT broker, e.g. "mqtt://192.168.1.10:1883"</li>
            <li> "<b>mqttUsername</b>" and "<b>mqttPassword</b>" (optional) - user credentials for MQTT authentication</li>
            <li> "<b>heartbeatInterval</b>" (optional) - interval in seconds for the heartbeat message (default: 60)</li>
            <li> "<b>deviceFilter</b>" (optional) - apply your filters for Fibaro HC3 device autodiscovery in case you need to limit the number of devices to be bridged with Home Assistant. <br>
            <details>
               <summary>Click here to see example</summary>
               <code>{"filter":"baseType", "value":["com.fibaro.actor"]}, {"filter":"deviceID", "value":[41,42]}, { MORE FILTERS MAY GO HERE }</code>.<br> Fibaro Filter API description and more examples could be found at https://manuals.fibaro.com/content/other/FIBARO_System_Lua_API.pdf => "fibaro:getDevicesId(filters)"
               <br><br>Use "deviceFilter", "deviceFilter2", "deviceFilter3" ... "deviceFilterX" to overcome Fibaro QuickApp variable length limitation. Use "," (commas) after each filter criterion as it is not added added automatically
            </details>
            </li>
    </li>
</ol>

## Already supported device types
   * Z-Wave hardware, and experimental Zigbee & Nice devices support
   * Sensors - Fibaro Motion Sensor, Fibaro Universal Sensor, Fibaro Flood Sensor, Fibaro Smoke/Fire Sensor, most of the generic sensors to measure temperature, humidity, brightness and so on
   * Energy and power meters
   * Charge level sensors for battery-powered devices
   * Lights - binary, dimmers and RGBW (no RGB for now)
   * Switches - binary and sound
   * Remote Controllers, where each key is binded to automation triggers visible in Home Assistant GUI
   * Thermostats (limited support for a few known vendors) 

## Credits

- **Original project:** [alexander-vitishchenko/hc3-to-mqtt](https://github.com/alexander-vitishchenko/hc3-to-mqtt) — MIT License
- **Sensor device_class fix:** [Eroi69](https://github.com/Eroi69/hc3-to-mqtt)
