# SASE-HACK-26
Society of Asian Scientists &amp; Engineers Hackathon 2026.

# Hydrometer

**Hydration tracking that doesn't rely on you remembering.**

Hydrometer is a smart bottle cap that automatically tracks water intake using a Hall-effect sensor to detect the position of a magnetic float inside the bottle. Instead of manually logging drinks, the system senses real drinking behavior directly — converting water level changes into daily hydration insights delivered through a companion mobile app.

---

## Problem

Most people don't meet daily hydration recommendations, not because they don't care, but because they forget. This is especially true for college students, whose long lecture blocks and irregular schedules make it easy to go hours without drinking water. Existing hydration apps rely on manual logging, which fails for the same reason the underlying problem exists in the first place — people forget.

## Solution

Hydrometer removes the need to remember by sensing hydration automatically:

- A magnetic float rides on the water surface inside the bottle
- A Hall-effect sensor detects the float's position in real time
- An onboard microcontroller converts that position into a volume reading
- An IMU filters out unreliable readings when the bottle is tilted or in motion
- Drink and refill events are detected automatically and synced to a companion iOS app over Bluetooth

## Current Status

This project is currently in the **simulation and design validation phase**. Due to the team's distributed hackathon setup, a physical prototype has not yet been built. Instead:

- Sensor logic, volume calibration, drink/refill detection, and tilt-gating have all been developed and validated in [Wokwi](https://wokwi.com), an electronics simulator, using a potentiometer as a stand-in for the Hall-effect sensor
- The physical enclosure and float/guide rail assembly have been designed in SolidWorks
- The companion iOS app UI has been built against a finalized BLE data contract, using mock data ahead of live hardware integration

If selected to advance, the next phase is assembling and calibrating the physical hardware using the BOM and architecture already validated in simulation.

## Features

**Core tracking**
- Automatic water level sensing (no manual logging)
- Drink and refill detection
- Real-time sync to mobile app
- Daily intake dashboard

**Smart insights**
- Drought window alerts (long gaps with no drinking)
- Time-of-day and weekday/weekend pattern view
- Consistency streaks, not just totals

**Personalization (roadmap)**
- Goals based on body weight and activity level
- Weather-adjusted hydration targets
- Athletic/performance mode

## Tech Stack

- **Firmware:** ESP32-C3 (Arduino framework), simulated and developed in Wokwi
- **Sensors:** DRV5053 Hall-effect sensor, MPU6050 IMU
- **Connectivity:** Bluetooth Low Energy (BLE)
- **Mobile app:** Swift / Xcode (iOS)
- **CAD / Enclosure:** SolidWorks

## Contributors

| Name | Role |
|---|---|
| Byron Manuel | Electronics |
| Clark Laforteza | SolidWorks / CAD |
| Jordan Benzon | Xcode / Mobile App |

## Disclaimer

Hydrometer is a hydration awareness tool, not a medical or diagnostic device. Insights are intended to help users notice their own drinking patterns and are not a substitute for medical advice.
