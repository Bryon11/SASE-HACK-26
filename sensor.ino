#include <Wire.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>

const int HALL_PIN = 34;

Adafruit_MPU6050 mpu;

int previousVolume = -1;
int dailyIntake = 0;

int pendingVolume = -1;
unsigned long pendingSince = 0;
const unsigned long STABLE_TIME_MS = 1500;

const float TILT_THRESHOLD_DEG = 15.0; // how far from upright is "too tilted"

int hallToVolume(int hall) {
  if (hall < 1000) return 100;
  else if (hall < 1500) return 200;
  else if (hall < 2000) return 300;
  else if (hall < 2500) return 400;
  else if (hall < 3000) return 500;
  else return 600;
}

bool isUpright() {
  sensors_event_t a, g, temp;
  mpu.getEvent(&a, &g, &temp);

  // Estimate tilt from accelerometer: when upright, most of gravity
  // should be on the Z axis, very little on X/Y.
  float pitch = atan2(a.acceleration.x,
                       sqrt(a.acceleration.y * a.acceleration.y +
                            a.acceleration.z * a.acceleration.z)) * 180.0 / PI;

  float roll = atan2(a.acceleration.y,
                      sqrt(a.acceleration.x * a.acceleration.x +
                           a.acceleration.z * a.acceleration.z)) * 180.0 / PI;

  return (abs(pitch) < TILT_THRESHOLD_DEG) && (abs(roll) < TILT_THRESHOLD_DEG);
}

void setup() {
  Serial.begin(115200);

  if (!mpu.begin()) {
    Serial.println("MPU6050 not found!");
    while (1) delay(10);
  }

  mpu.setAccelerometerRange(MPU6050_RANGE_8_G);
  mpu.setGyroRange(MPU6050_RANGE_500_DEG);
  mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);
}

void loop() {
  bool upright = isUpright();

  if (!upright) {
    Serial.println("TILTED - ignoring Hall reading");
    delay(200);
    return; // skip everything else this loop
  }

  int hallValue = analogRead(HALL_PIN);
  int rawVolume = hallToVolume(hallValue);

  if (previousVolume == -1) {
    previousVolume = rawVolume;
    pendingVolume = rawVolume;
    pendingSince = millis();
  }

  if (rawVolume != pendingVolume) {
    pendingVolume = rawVolume;
    pendingSince = millis();
  }

  bool isStable = (millis() - pendingSince) >= STABLE_TIME_MS;

  if (isStable && pendingVolume != previousVolume) {
    int currentVolume = pendingVolume;

    if (currentVolume < previousVolume) {
      int drinkAmount = previousVolume - currentVolume;
      dailyIntake += drinkAmount;

      Serial.print("DRINK DETECTED: -");
      Serial.print(drinkAmount);
      Serial.println(" mL");
    }
    else {
      int refillAmount = currentVolume - previousVolume;

      Serial.print("REFILL DETECTED: +");
      Serial.print(refillAmount);
      Serial.println(" mL");
    }

    previousVolume = currentVolume;
  }

  Serial.print("Volume: ");
  Serial.print(rawVolume);
  Serial.print(" mL | Daily Intake: ");
  Serial.print(dailyIntake);
  Serial.println(" mL | Status: Upright");

  delay(200);
}
