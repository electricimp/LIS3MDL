# LIS3MDL Magnetometer Class

This class allows the Electric Imp to drive the LIS3MDL Magnetometer ([datasheet](http://www.st.com/web/catalog/sense_power/FM89/SC1449/PF255198) / [application note](http://www.st.com/st-web-ui/static/active/en/resource/technical/document/application_note/DM00136626.pdf)).  This device is a low-power, highly configurable 3-axis magnetic sensor with support for user-defined interrupts.

The sensor supports I²C and SPI interfaces.  This library currently only supports the I²C interface.

**To add this library to your project, add `#require "LIS3MDL.class.nut:2.0.0"` to the top of your device code.**

## Examples and Hardware

For an example of this hardware integrated in a reference design, see the [Nora overview](https://electricimp.com/docs/hardware/resources/reference-designs/nora/).


## Class Usage

### Constructor: LIS3MDL(*i2c, [address]*)

Creates and initializes an object representing the LIS3MDL magnetometer.  Note that this device must be configured with [`setConversionMode(mode)`](#setconversionmodemode) before its sensors can be read from.

| Parameter | Type         | Default    | Description |
|-----------|--------------|------------|-------------|
| i2c       | hardware.i2c | (Required) | A pre-configured [I²C object](https://electricimp.com/docs/api/hardware/i2c/) |
| address   | Byte         | 0x1C       | The (8-bit) I²C address for the LIS3MDL |


```squirrel
local i2c = hardware.i2c89;
i2c.configure(CLOCK_SPEED_400_KHZ);

// Use alternate I2C address
magnetometer <- LIS3MDL(i2c, 0x3C);
```


### setScale(*scale*)

Sets the full-scale range that the LIS3MDL should measure values across and returns the actual scale selected.  Supported *scale* values are 4, 8, 12, or 16.  Each value represents a maximum magnitude measured in gauss (e.g. 4 represents a ±4 gauss range).  This input must be one of the four allowable values.  Any other input value will be rounded down to the nearest legal value.  The device starts with a full-scale range of 4 gauss by default.

```squirrel
magnetometer.setScale(8);
```


### setDataRate(*dataRate*)

Sets the rate at which the LIS3MDL prepares new data readings and returns the actual data rate selected (or `LIS3MDL.DATA_RATE_FAST` when applicable).   See chart below for supported data rates.  If an unsupported data rate is selected the data rate will be rounded down to the closest supported rate.  The device starts with a data rate of 40Hz by default (Note: this is a different rate than that specified in the datasheet).

| Rate                    | Description |
|-------------------------|-------------|
| 0.625                   | Hz          |
| 1.25                    | Hz          |
| 2.5                     | Hz          |
| 5                       | Hz          |
| 10                      | Hz          |
| 20                      | Hz          |
| 40                      | Hz          |
| 80                      | Hz          |
| `LIS3MDL.DATA_RATE_FAST` | Data rates between 155 Hz and 1kHz are determined by the operating mode, as described below. |

```squirrel
// Set data rate to 2.5 Hz
local rate = magnetometer.setDataRate(2.5);
server.log("Magnetometer is running at " + rate + " Hz");
```

#### Fast Data Rate Configuration
Data rates under this setting are dependent on the operating mode set with [`setPerformance(performanceRating)`](#setperformanceperformancerating).

| Performance Rating       | Data Rate (Hz)|
|--------------------------|---------------|
| Ultra-high performance   | 155           |
| High-performance         | 300           |
| Medium-performance       | 560           |
| Low-power                | 1000          |


### setPerformance(*performanceRating*)

Sets the performance vs. power tradeoff used when measuring on the three axes.  Increased performance will result in less noise, which lowers the threshold for the minimum detectable field.  It will also result in longer start-up times.  See the chart below for how to configure *performanceRating*. The device starts in low-power mode by default.

| *performanceRating* | Meaning                | Time to First Read |
|---------------------|------------------------|--------------------|
| 0                   | Low power              | 1.2 ms             |
| 1                   | Medium performance     | 1.65 ms            |
| 2                   | High performance       | 3.23 ms            |
| 3                   | Ultra-high performance | 6.4 ms             |


```squirrel
// Set data rate to 155 Hz
magnetometer.setPerformance(3);
magnetometer.setDataRate(LIS3MDL.DATA_RATE_FAST);
```

### setLowPower(*state*)

Switches the LIS3MDL in or out of low-power mode.  In low-power mode, the output data rate is dropped to 0.625 Hz and the system performs the minimum number of averages in its calculations.  Switching back out of low-power mode will restore the previous output data rate. The device starts with low-power mode disabled.

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

### setConversionMode(*mode*)

Use *setConversionMode* to enable measurements on all three axes.

The device is started in `LIS3MDL.SHUT_DOWN_MODE` by default.  Note that powering down with this method does not completely disable the device.  When powered down, all registers are still accessible, but the sensor will not collect new readings and calls to [`readAxes(callback)`](#readaxescallback) will always return the same value.

In `LIS3MDL.ONE_SHOT_MODE` the device immediately takes a single measurement then resets to `LIS3MDL.SHUT_DOWN_MODE`.  Note that one-shot mode has to be used with sampling frequency from 0.625 Hz to 80Hz.

In `LIS3MDL.CONTINUOUS_MODE` the device takes continuous measurements.

| *mode* | Description |
|---------------------|------------------------|
| LIS3MDL.SHUT_DOWN_MODE    | Powers down the magnetic sensor. |
| LIS3MDL.ONE_SHOT_MODE        | Immediately take a single measurement then returns to shut-down mode.  |
| LIS3MDL.CONTINUOUS_MODE   | Takes continuous measurements.  |

```squirrel
// Take a single reading
magnetometer.setConversionMode(LIS3MDL.ONE_SHOT_MODE);
server.log(magnetometer.readAxes().x);

imp.sleep(1);

// This log will show the same value as before
server.log(magnetometer.readAxes().x);
```

### readAxes([*callback*])

The *readAxes* method reads and returns the latest measurement from the magnetic field sensor.  The reading is in the form of a squirrel table with `x`, `y`, and `z` fields.  The value from the sensor reading is automatically scaled to gauss.

The *readAxes* method takes an optional callback for asynchronous operation. If a callback is specified, then the reading table will be passed to the callback as the only parameter.  If not, the reading table will be returned.

#####Synchronous Example:

```squirrel
magnetometer.setConversionMode(LIS3MDL.ONE_SHOT_MODE);
local reading = magnetometer.readAxes();
server.log("x: " + reading.x + " y: " + reading.y + " z: " + reading.z);
```

#####Asynchronous Example:
```squirrel
magnetometer.setConversionMode(LIS3MDL.ONE_SHOT_MODE);
magnetometer.readAxes(function(reading) {
    server.log("x: " + reading.x + " y: " + reading.y + " z: " + reading.z);
});
```

### readStatus()
Parses and returns the value of the LIS3MDL's status register.  The return value is a Squirrel table with following keys and booleans as values:

| Key   | Description                                            |
|-------|--------------------------------------------------------|
| ZYXOR | Whether a X-, Y-, and Z-axis data overrun has occured  |
| ZOR   | Whether a Z-axis data overrun has occured              |
| YOR   | Whether a Y-axis data overrun has occured              |
| XOR   | Whether a X-axis data overrun has occured              |
| ZYXDA | Whether there is new X-, Y-, and Z-axis data available |
| ZDA   | Whether there is new Z-axis data available             |
| YDA   | Whether there is new Y-axis data available             |
| XDA   | Whether there is new X-axis data available             |


```squirrel
magnetometer.setLowPower(true)
magnetometer.setConversionMode(LIS3MDL.CONTINUOUS_MODE)

function statusLoop() {
    local status = magnetometer.readStatus();
    if(status.ZYXOR) {
        server.log("Overrun Occurred.");
        server.log("X overrun: " + status.XOR);
        server.log("Y overrun: " + status.YOR);
        server.log("Z overrun: " + status.ZOR);
    }
    if(status.ZYXDA) {
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

### configureInterrupt(*isEnabled, [threshold, options]*)

Sets up the interrupt system on the LIS3MDL.  The device starts with interrupts disabled by default.

#### Parameters

| Parameter   | Type    | Default    | Description |
|-------------|---------|------------|-------------|
| *isEnabled* | Boolean | (Required) | Whether the LIS3MDL should generate interrupts. |
| *threshold* | Integer | 4          | The threshold magnitude needed to trigger an interrupt.  Threshold is in gauss.  This value will be interpreted as a 16-bit unsigned integer and represents an absolute value (i.e. a measured value of -20 will trigger an interrupt with a threshold of 10).
| *options*   | Byte    | 0x00       | Configuration options combined with the bitwise OR operator.  See the **options** table below for available options.

#### Options

| Option         | Interrupt Default | Description |
|----------------|-------------|-------------|
| `LIS3MDL.AXIS_X` | Disabled by default | When this option is passed in the LIS3MDL will listen for interrupts on the x-axis |
| `LIS3MDL.AXIS_Y` | Disabled by default | When this option is passed in the LIS3MDL will listen for interrupts on the y-axis |
| `LIS3MDL.AXIS_Z` | Disabled by default | When this option is passed in the LIS3MDL will listen for interrupts on the z-axis |
| `LIS3MDL.INTERRUPT_ACTIVEHIGH` | Device is ACTIVE LOW by default | When this option is passed in the interrupt pin is configured in active-high mode. |
| `LIS3MDL.INTERRUPT_LATCH` | Latching is disabled by default | When this option is passed in latching will be enabled.  If latching is disabled, the interrupt pin may change state even if [`readInterruptStatus()`](#readinterruptstatus) is not called. |

```squirrel
// Enable interrupt monitoring on the X- and Y-axes with a threshold of 3 gauss
magnetometer.configureInterrupt(true, 3, LIS3MDL.AXIS_X | LIS3MDL.AXIS_Y);
```
```squirrel
// Disable interrupt monitoring
magnetometer.configureInterrupt(false);
```

### readInterruptStatus()

Returns the interrupt source register on the LIS3MDL.  The return value is a Squirrel table (see chart below).

| Key        | Type | Description                                                   |
|------------|------------|---------------------------------------------------------------|
| x_positive | boolean | If *true* the X-axis value exceeded the threshold on the positive side. |
| x_negative | boolean | If *true* the X-axis value exceeded the threshold on the negative side. |
| y_positive | boolean | If *true* the Y-axis value exceeded the threshold on the positive side. |
| y_negative | boolean | If *true* the Y-axis value exceeded the threshold on the negative side. |
| z_positive | boolean | If *true* the Z-axis value exceeded the threshold on the positive side. |
| z_negative | boolean | If *true* the Z-axis value exceeded the threshold on the negative side. |
| overflow   | boolean | If *true* a value overflowed the internal measurement range.            |
| interrupt  | integer | The state of the interrupt pin at the time of the event. |


### reset()

Performs a software reset of the LIS3MDL's registers.  After calling reset you will need to reconfigure the magnetometer's settings.


```squirrel
// Something bad just happened
magnetometer.reset();

// Start over
magnetometer.setDataRate(80);
magnetometer.setConversionMode(LIS3MDL.ONE_SHOT_MODE);
local reading = magnetometer.readAxes();
server.log("x: "+reading.x+" y: "+reading.y+" z: "+reading.z);
```

### init()

Synchronizes the object's data-reading scale with that stored on the device.  This method is automatically called by the constructor and reset functions.


# License

The LIS3MDL class is licensed under the [MIT License](./LICENSE).
