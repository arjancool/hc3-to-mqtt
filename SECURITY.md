# Security Policy

## Reporting a vulnerability

Please **do not open a public GitHub issue** for security-sensitive reports.

Instead, open a GitHub Security Advisory on this repository (Security tab →
"Report a vulnerability"). Include:

- a description of the issue and the impact you observed
- steps to reproduce, and the QuickApp version you were running
- any relevant log excerpts (with credentials redacted)

A maintainer will acknowledge the report and work with you on remediation. We
will credit reporters in the changelog unless you prefer to stay anonymous.

## Scope

This is a Fibaro HC3 QuickApp that bridges device state to an MQTT broker. The
attack surface includes:

- the Lua sources in `src/` and the bundled `.fqa`
- the MQTT topic conventions (`homeassistant/+/+/...`, `homie/+/...`)
- the QuickApp variables read from the HC3 (`mqttUrl`, `mqttUsername`,
  `mqttPassword`, `mqttClientId`, `heartbeatInterval`, `heartbeatIncludeMeta`,
  `deviceFilter*`)

Out of scope:

- vulnerabilities in Fibaro's HC3 firmware, the MQTT broker, or Home Assistant
  itself — please report those upstream

## Known operational considerations

Even when the code is correct, the following operational choices materially
affect security. They are documented here, not treated as bugs:

- **Plain `mqtt://`** transmits credentials and device state in clear text.
  Use `mqtts://` with a broker that enforces TLS.
- **MQTT broker ACLs** must be configured to limit who can subscribe to the
  bridge topics. Anyone with read access can observe device state.
- **`heartbeatIncludeMeta=false`** can be set to omit IP/version/device-count
  metadata from the heartbeat topic on shared brokers.
- **QuickApp variables are not encrypted at rest.** Anyone with HC3 admin
  access can read the MQTT password.
- **Embedded credentials in `mqttUrl`** (e.g. `mqtt://user:pass@host`) are
  logged with the user/pass placeholder substitution applied via
  `sanitizeMqttUrl`. Prefer the dedicated `mqttUsername` / `mqttPassword`
  variables.
