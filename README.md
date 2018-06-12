# LIS3MDL Magnetometer Class #

This class allows the Electric Imp to drive the LIS3MDL Magnetometer ([datasheet](http://www.st.com/web/catalog/sense_power/FM89/SC1449/PF255198) and [application note](http://www.st.com/st-web-ui/static/active/en/resource/technical/document/application_note/DM00136626.pdf)). This device is a low-power, highly configurable three-axis magnetic sensor with support for user-defined interrupts.

The sensor supports I&sup2;C and SPI interfaces. This library currently only supports the I&sup2;C interface.

**To add this library to your project, add** `#require "LIS3MDL.class.nut:2.0.0"` **to the top of your device code.**

## Examples and Hardware ##

For an example of this hardware integrated in a reference design, see the [Nora overview](https://developer.electricimp.com/hardware/resources/reference-designs/nora/) in the Electric Imp Dev Center.

## Class Usage ##

### Constructor: LIS3MDL(*i2cBus[, i2cAddress]*) ###

Creates and initializes an object representing the LIS3MDL magnetometer. This device must be configured with [*setConversionMode()*](#setconversionmodemode) before its sensors can be read.

#### Parameters ####

| Parameter | Type | Default Value | Description |
| --- | --- | --- | --- |
| i2cBus | hardware.i2c | N/A | A pre-configured [I&2up2;C object](https://developer.electricimp.com/api/hardware/i2c/) |
| i2cAddress | Byte | 0x1C | The LIS3MDL’s 8-bit I&sup2;C address |

#### Example ####

```squirrel
#require "LIS3MDL.class.nut:2.0.0"

local i2c = hardware.i2c89;
i2c.configure(CLOCK_SPEED_400_KHZ);

// Use alternate I2C address - SA1 pin tied high
magnetometer <- LIS3MDL(i2c, 0x3C);
```

## Class Methods ##

### setScale(*scale*) ###

Sets the full-scale range that the LIS3MDL should measure values across and returns the actual scale selected. Supported *scale* values are 4, 8, 12 and 16. Each value represents a maximum magnitude measured in gauss (eg. 4 represents a &plusmn;4 gauss range). 

This input must be one of the four allowable values. Any other input value will be rounded down to the nearest legal value. The device starts with a full-scale range of 4 gauss by default.

```squirrel
magnetometer.setScale(8);
```

### setDataRate(*dataRate*) ###

Sets the rate at which the LIS3MDL prepares new data readings and returns the actual data rate selected (or *LIS3MDL.DATA_RATE_FAST* when applicable). See table below for supported data rates. If an unsupported data rate is selected, the data rate will be rounded down to the closest supported rate. The device starts with a data rate of 40Hz by default &mdash; a different rate than that specified in the datasheet.

| Rate | Description |
| --- | --- |
| 0.625 | Hz value |
| 1.25 | Hz value |
| 2.5 | Hz value |
| 5 | Hz value |
| 10 | Hz value |
| 20 | Hz value |
| 40 | Hz value |
| 80 | Hz value |
| `LIS3MDL.DATA_RATE_FAST` | Data rates between 155Hz and 1kHz are determined by the operating mode, as described below. |

#### Fast Data Rate Configuration ####

Data rates under this setting are dependent on the operating mode set with [*setPerformance()*](#setperformanceperformancerating).

| Performance Rating       | Data Rate (Hz) |
| ------------------------ | -------------- |
| Ultra-high performance   | 155            |
| High-performance         | 300            |
| Medium-performance       | 560            |
| Low-power                | 1000           |

#### Example ####

```squirrel
// Set data rate to 2.5Hz
local rate = magnetometer.setDataRate(2.5);
server.log("Magnetometer is running at " + rate + "Hz");
```

### setPerformance(*performanceRating*) ###

Sets the performance versus power trade-off used when measuring on the three axes. Increased performance will result in less noise, which lowers the threshold for the minimum detectable field. It will also result in longer start-up times. The device starts in low-power mode by default.

The parameter performanceRating is an integer between 0 and 3, assigned as follows:

| *performanceRating* | Meaning                | Time to First Read |
|---------------------|------------------------|--------------------|
| 0                   | Low power              | 1.2ms             |
| 1                   | Medium performance     | 1.65ms            |
| 2                   | High performance       | 3.23ms            |
| 3                   | Ultra-high performance | 6.4ms             |

#### Example ####

```squirrel
// Set data rate to 155 Hz
magnetometer.setPerformance(3);
magnetometer.setDataRate(LIS3MDL.DATA_RATE_FAST);
```

### setLowPower(*state*) ###

Switches the LIS3MDL in or out of low-power mode. In low-power mode, the output data rate is dropped to 0.625Hz and the system performs the minimum number of averages in its calculations. Switching back out of low-power mode will restore the previous output data rate. The device starts with low-power mode disabled.

#### Example ####

```squirrel
// A very low-power magnetic field polling snippet

// Enable the LIS3MDL
magnetometer.setConversionMode(LIS3MDL.CONTINUOUS_MODE);

// Use the LIS3MDL in low power mode
magnetometer.setLowPower(true);

// Configure the Imp to wake from deep sleep on the LIS3MDL interrupt pin
hardware.pin1.configure(DIGITAL_IN_WAKEUP, function() {
  // Take a reading
  magnetometer.readAxes(function(reading) {
    server.log("x: " + reading.x + " y: " + reading.y + " z: " + reading.z);
  });
});

// Configure the LIS3MDL to wake the Imp from deep sleep mode if a magnetic field over 3 gauss is detected.
magnetometer.configureInterrupt(true, 3, LIS3MDL.AXIS_X);

// Put the Imp in deep sleep for one day.
imp.deepsleepfor(86400);
```

### setConversionMode(*mode*) ###

Use *setConversionMode()* to enable measurements on all three axes. Available modes are tabled below. The device is started in *LIS3MDL.SHUT_DOWN_MODE* by default. 

**Note** Powering down with this method does not completely disable the device. When powered down, all registers are still accessible, but the sensor will not collect new readings and calls to [*readAxes()*](#readaxescallback) will always return the same value.

| *mode* | Description |
| --- | --- |
| *LIS3MDL.SHUT_DOWN_MODE* | Powers down the magnetic sensor |
| *LIS3MDL.ONE_SHOT_MODE* | Immediately take a single measurement then returns to shut-down mode (*LIS3MDL.SHUT_DOWN_MODE*). One-shot mode must be used with sampling frequency from 0.625 Hz to 80Hz |
| *LIS3MDL.CONTINUOUS_MODE* | Takes continuous measurements |

#### Example ####

```squirrel
// Take a single reading
magnetometer.setConversionMode(LIS3MDL.ONE_SHOT_MODE);
server.log(magnetometer.readAxes().x);
imp.sleep(1);

// This log will show the same value as before
server.log(magnetometer.readAxes().x);
```

### readAxes(*[callback]*) ###

The *readAxes()* method reads and returns the latest measurement from the magnetic field sensor. The reading is in the form of a table with *x*, *y* and *z* keys. The value from the sensor reading is automatically scaled to gauss.

The *readAxes()* method takes an optional callback for asynchronous operation. If a callback is specified, then the reading table will be passed to the callback as the only parameter. If not, the method will block until the reading had been taken, and the table will be returned.

#### Synchronous Example ####

```squirrel
magnetometer.setConversionMode(LIS3MDL.ONE_SHOT_MODE);
local reading = magnetometer.readAxes();
server.log("x: " + reading.x + " y: " + reading.y + " z: " + reading.z);
```

#### Asynchronous Example ####

```squirrel
magnetometer.setConversionMode(LIS3MDL.ONE_SHOT_MODE);
magnetometer.readAxes(function(reading) {
  server.log("x: " + reading.x + " y: " + reading.y + " z: " + reading.z);
});
```

### readStatus() ###

Parses and returns the value of the LIS3MDL’s status register. A table is returned with following keys and booleans as values:

| Key   | Description                                            |
|-------|--------------------------------------------------------|
| *ZYXOR* | Whether a X-, Y-, and Z-axis data overrun has occured  |
| *ZOR*   | Whether a Z-axis data overrun has occured              |
| *YOR*   | Whether a Y-axis data overrun has occured              |
| *XOR*   | Whether a X-axis data overrun has occured              |
| *ZYXDA* | Whether there is new X-, Y-, and Z-axis data available |
| *ZDA*   | Whether there is new Z-axis data available             |
| *YDA*   | Whether there is new Y-axis data available             |
| *XDA*   | Whether there is new X-axis data available             |

#### Example ####

```squirrel
magnetometer.setLowPower(true);
magnetometer.setConversionMode(LIS3MDL.CONTINUOUS_MODE);

function statusLoop() {
  local status = magnetometer.readStatus();
  if (status.ZYXOR) {
    server.log("Overrun Occurred.");
    server.log("X overrun: " + status.XOR);
    server.log("Y overrun: " + status.YOR);
    server.log("Z overrun: " + status.ZOR);
  }
  
  if (status.ZYXDA) {
    server.log("New Data.");
    server.log("X data available: " + status.XDA);
    server.log("Y data available: " + status.YDA);
    server.log("Z data available: " + status.ZDA);
    local reading = magnetometer.readAxes();
    server.log("x: "+reading.x+" y: "+reading.y+" z: "+reading.z);
  }
  
  imp.wakeup(1, statusLoop);
}

statusLoop();
```

### configureInterrupt(*isEnabled[, threshold][, options]*) ###

This method sets up the interrupt system on the LIS3MDL. The device starts with interrupts disabled by default.

#### Parameters ####

| Parameter | Type | Default Value | Description |
| --- | --- | --- | --- |
| *isEnabled* | Boolean | N/A | Whether the LIS3MDL should generate interrupts |
| *threshold* | Integer | 4 | The threshold magnitude needed to trigger an interrupt. Threshold is in gauss. This value will be interpreted as a 16-bit unsigned integer and represents an absolute value (ie. a measured value of -20 will trigger an interrupt with a threshold of 10).
| *options* | Byte | 0x00 | Configuration options combined with the bitwise OR operator. See the ‘Options’ table below for available values.

#### Options ####

| Option         | Interrupt Default | Description |
|----------------|-------------|-------------|
| *LIS3MDL.AXIS_X* | Disabled | When this option is passed in the LIS3MDL will listen for interrupts on the x-axis |
| *LIS3MDL.AXIS_Y* | Disabled | When this option is passed in the LIS3MDL will listen for interrupts on the y-axis |
| *LIS3MDL.AXIS_Z* | Disabled | When this option is passed in the LIS3MDL will listen for interrupts on the z-axis |
| *LIS3MDL.INTERRUPT_ACTIVEHIGH* | Device is ACTIVE LOW by default | When this option is passed in the interrupt pin is configured in active-high mode |
| *LIS3MDL.INTERRUPT_LATCH* | Disabled | When this option is passed in latching will be enabled. If latching is disabled, the interrupt pin may change state even if [*readInterruptStatus()*](#readinterruptstatus) is not called |

#### Examples ####

```squirrel
// Enable interrupt monitoring on the X- and Y-axes with a threshold of 3 gauss
magnetometer.configureInterrupt(true, 3, LIS3MDL.AXIS_X | LIS3MDL.AXIS_Y);
```

```squirrel
// Disable interrupt monitoring
magnetometer.configureInterrupt(false);
```

### readInterruptStatus() ###

This method returns the interrupt source register on the LIS3MDL. The return value is a table with following keys and booleans as values:

| Key | Type | Description |
| --- | --- | --- |
| *x_positive* | Boolean | If *true* the X-axis value exceeded the threshold on the positive side |
| *x_negative* | Boolean | If *true* the X-axis value exceeded the threshold on the negative side |
| *y_positive* | Boolean | If *true* the Y-axis value exceeded the threshold on the positive side |
| *y_negative* | Boolean | If *true* the Y-axis value exceeded the threshold on the negative side |
| *z_positive* | Boolean | If *true* the Z-axis value exceeded the threshold on the positive side |
| *z_negative* | Boolean | If *true* the Z-axis value exceeded the threshold on the negative side |
| *overflow*   | Boolean | If *true* a value overflowed the internal measurement range  |
| *interrupt*  | Integer | The state of the interrupt pin at the time of the event |

### reset() ###

This method performs a software reset of the LIS3MDL’s registers. After calling reset you will need to reconfigure the magnetometer’s settings.

```squirrel
// Something bad just happened
magnetometer.reset();

// Start over
magnetometer.setDataRate(80);
magnetometer.setConversionMode(LIS3MDL.ONE_SHOT_MODE);
local reading = magnetometer.readAxes();
server.log("x: "+reading.x+" y: "+reading.y+" z: "+reading.z);
```

### init() ###

Synchronizes the object’s data-reading scale with that stored on the device. This method is automatically called by the constructor and *reset()* functions.

## License ##

The LIS3MDL class is licensed under the [MIT License](./LICENSE).
