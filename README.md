# LIS3MDL Magnetometer Class

This class allows the Electric Imp to drive the LIS3MDL Magnetometer ([datasheet](http://www.st.com/web/catalog/sense_power/FM89/SC1449/PF255198) / [application note](http://www.st.com/st-web-ui/static/active/en/resource/technical/document/application_note/DM00136626.pdf)).  This device is a low-power, highly configurable 3-axis magnetic sensor with support for user-defined interrupts.

The sensor supports I²C and SPI interfaces.  This library currently only supports the I²C interface.

To add this library to your project, add #require "LIS3MDL.class.nut:2.0.0" to the top of your device code

## Examples and Hardware

For an example of this hardware integrated in a reference design, see the [Nora overview](https://electricimp.com/docs/hardware/resources/reference-designs/nora/).


## Class Usage

### Constructor: LIS3MDL(*i2c, [address]*)

Creates and initializes an object representing the LIS3MDL magnetometer.  Note that this device must be enabled with a call to [`enable(state)`](#enablestate) before its sensors can be read from.

| Parameter | Type         | Default    | Description |
|-----------|--------------|------------|-------------|
| i2c       | hardware.i2c | (Required) | A pre-configured [I²C object](https://electricimp.com/docs/api/hardware/i2c/) |
| address   | Byte         | 0x1C       | The (8-bit) I²C address for the LIS3MDL |


```squirrel
#require "LIS3MDL.class.nut:2.0.0"

local i2c = hardware.i2c89;
i2c.configure(CLOCK_SPEED_400_KHZ);

// Use alternate I2C address - SA1 pin tied high
magnetometer <- LIS3MDL(i2c, 0x3C);

// Enable once we're ready to use
magnetometer.enable();
```

### init()

Synchronizes the object's data-reading scale with that stored on the device.

This method should be called after hard power-cycles, but is automatically called by the constructor and reset functions.

```squirrel
magneto <- LIS3MDL(spi, 0x3C);

// ... Reboot the LIS3MDL manually ...

magnetometer.init();
// Now we can continue
```

### enable(*state*)

Sets whether the magnetic sensor should be powered.  The device starts with this disabled by default.

Note that powering down with this method does not completely disable the device.  When powered down, all registers are still accessible, but the sensor will not collect new readings and calls to [`readAxes(callback)`](#readaxescallback) will always return the same value.

For a way to reduce power less drastically by reducing output rates and processing, see [`setLowPower(state)`](#setlowpowerstate).

```squirrel
// Power down if we don't need the sensor to be polling
magnetometer.enable(false);

// Re-enable sensor in 1 minute
imp.wakeup(60, function() {
    magnetometer.enable(true);
    local reading = magnetometer.readAxis(LIS3MDL.AXIS_X);
    // Use reading
});
```

### setPerformance(*performanceRating*)

Sets the performance vs. power tradeoff used when measuring on the three axes.  Increased performance will result in less noise, which lowers the threshold for the minimum detectable field.  It will also result in longer start-up times.  The device starts in low-power mode by default.

*performanceRating* is an integer between 0 and 3, assigned as follows:

| *performanceRating* | Meaning                | Time to First Read |
|---------------------|------------------------|--------------------|
| 0                   | Low power              | 1.2 ms             |
| 1                   | Medium performance     | 1.65 ms            |
| 2                   | High performance       | 3.23 ms            |
| 3                   | Ultra-high performance | 6.4 ms             |


```squirrel
magnetometer.setPerformance(0);
```

### setDataRate(*dataRate*)

Sets the rate at which the LIS3MDL prepares new data readings. Returns the actual data rate selected (or `LIS3MDL.DATA_RATE_FAST` when applicable). The device starts with a data rate of 10Hz by default.

*dataRate* is a number between 0.625 and 80 representing the output rate in Hz or the value `LIS3MDL.DATA_RATE_FAST`.  The LIS3MDL allows for several discrete output rates, so the actual output rate will be the closest one less than or equal to the one specified, taken from the following table:

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

#### Fast Data Rate Configuration
Data rates under this setting are dependent on the operating mode set with [`setPerformance(performanceRating)`](#setperformanceperformancerating).

| Performance Rating       | Data Rate (Hz)|
|--------------------------|---------------|
| Ultra-high performance   | 155           |
| High-performance         | 300           |
| Medium-performance       | 560           |
| Low-power                | 1000          |


```squirrel
// Set data rate to 2.5 Hz
magnetometer.setDataRate(2.5);

// Set data rate to 155 Hz
magnetometer.setPerformance(3);
magnetometer.setDataRate(LIS3MDL.DATA_RATE_FAST);
```

### setScale(*scale*)

Sets the full-scale range that the LIS3MDL should measure values across.  Returns the actual scale selected.  The device starts with a full-scale range of 4 gauss by default.

*scale* is an integer with value 4, 8, 12, or 16.  Each value represents a maximum magnitude measured in gauss (e.g. 4 represents a ±4 gauss range).  This input must be one of the four allowable values.  Any other input value will be rounded down to the nearest legal value.



```squirrel
magnetometer.setScale(8);
```

### setLowPower(*state*)

Switches the LIS3MDL in or out of low-power mode.  The device starts with this disabled by default.

In low-power mode, the output data rate is dropped to 0.625 Hz and the system performs the minimum number of averages in its calculations.  Switching back out of low-power mode will restore the previous output data rate.

For a way to reduce power more drastically by turning off the sensors, see [`enable(state)`](#enablestate).

```squirrel
// A very low-power magnetic field polling snippet

// Use the LIS3MDL in low power mode
magnetometer.setLowPower(true);

// Configure the Imp to wake from deep sleep on the LIS3MDL interrupt pin
hardware.pin1.configure(DIGITAL_IN_WAKEUP, function() {
    // Do something
});

// Configure the LIS3MDL to wake the Imp from deep sleep mode
magnetometer.configureInterrupt(true, 500, LIS3MDL.AXIS_X);

// Put the Imp in deep sleep - it will be woken if a magnetic field is detected or in a day, whichever comes first
imp.deepsleepfor(86400);


```

### setConversionType(*conversionType*)

Switches between continuous and single conversion types.  The PN532 is started in single conversion mode by default.

*conversionType* should be `LIS3MDL.CONVERSION_TYPE_SINGLE` to immediately take a single measurement or `LIS3MDL.CONVERSION_TYPE_CONTINUOUS` for continuous collection.  Note that single-conversion mode has to be used with sampling frequency from 0.625 Hz to 80Hz and resets the device into disabled mode after each call.


```squirrel
// Start in single-conversion mode
magnetometer.setConversionType(LIS3MDL.CONVERSION_TYPE_SINGLE);

server.log(magnetometer.readAxes().x);
imp.sleep(1);

// This log will show the same value as before
server.log(magnetometer.readAxes().x);

// Re-enable the device to get a new reading
magnetometer.enable(true);
server.log(magnetometer.readAxes().x);
```

### readStatus()

Parses and returns the value of the LIS3MDL's status register.

The return value is a Squirrel table with following keys and booleans as values:

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
// A polling loop without interrupts

function loop() {
    local status = magnetometer.readStatus();
    if(status.XOR) {
        local data = mangeto.readAxes();
        // Process data
    }

    // Try again in a second
    imp.wakeup(1, loop);
}

loop();
```

### configureInterrupt(*isEnabled, [threshold, options]*)

Sets up the interrupt system on the LIS3MDL.  The device starts with this disabled by default.

#### Parameters

| Parameter   | Type    | Default    | Description |
|-------------|---------|------------|-------------|
| *isEnabled* | Boolean | (Required) | Whether the LIS3MDL should generate interrupts. |
| *threshold* | Integer | 0          | The threshold magnitude needed to trigger an interrupt.  This value will be interpreted as a 16-bit unsigned integer and represents an absolute value (i.e. a measured value of -20 will trigger an interrupt with a threshold of 10).
| *options*   | Byte    | 0x00       | Configuration options combined with the bitwise OR operator.  See the **options** table below for available options.

#### Options

| Option         | Description |
|----------------|-------------|
| `LIS3MDL.AXIS_X` | Whether the LIS3MDL should listen for interrupts on the x-axis |
| `LIS3MDL.AXIS_Y` | Whether the LIS3MDL should listen for interrupts on the y-axis |
| `LIS3MDL.AXIS_Z` | Whether the LIS3MDL should listen for interrupts on the z-axis |
| `LIS3MDL.INTERRUPT_ISACTIVEHIGH` | Whether the interrupt pin is configured in active-high mode.  **WARNING: This option will likely cause significant power usage.**  This device uses an open-drain topology to generate interrupt signals and will always burn power when low. To generate a wakeup signal for the Imp, keep the LIS3MDL in active-low mode and invert the signal before it reaches the Imp's wakeup pin.|
| `LIS3MDL.INTERRUPT_DONTLATCH` | Whether latching mode should be disabled.  If latching is disabled, the interrupt pin may change state even if [`readInterruptStatus()`](#readinterruptstatus) is not called. |


```squirrel
// Enable interrupt monitoring on the X- and Y-axes with a threshold of 200
magnetometer.configureInterrupt(true, 200, LIS3MDL.AXIS_X | LIS3MDL.AXIS_Y);

// Disable interrupt monitoring
magnetometer.configureInterrupt(false);
```

### readInterruptStatus()

Parses and returns the interrupt source register on the LIS3MDL.

The return value is a Squirrel table with following keys and booleans as values:

| Key        | Description                                                   |
|------------|---------------------------------------------------------------|
| x_positive | The X-axis value exceeded the threshold on the positive side. |
| x_negative | The X-axis value exceeded the threshold on the negative side. |
| y_positive | The Y-axis value exceeded the threshold on the positive side. |
| y_negative | The Y-axis value exceeded the threshold on the negative side. |
| z_positive | The Z-axis value exceeded the threshold on the positive side. |
| z_negative | The Z-axis value exceeded the threshold on the negative side. |
| overflow   | A value overflowed the internal measurement range.            |
| interrupt  | An interrupt event has occured (value always matches interrupt pin state) |

### readAxes([*callback*])

Returns a reading from the magnetic field sensor on all three axes.  The value from the sensor is automatically scaled to be in units of gauss.

If the callback is specified, then the data will be passed to the callback as the only parameter.  If not, the data will be returned immediately.

The reading is in the form of a squirrel table with `x`, `y`, and `z` fields.


```squirrel
function loop() {
    local reading = magnetometer.readAxes();

    // Do something with the x value
    process(reading.x);

    // Rerun in a second
    imp.wakeup(1, loop);
}

loop();
```

### reset()

Performs a software reset of the LIS3MDL's registers.


```squirrel
// Something bad just happened
magnetometer.reset();

// Start over
magnetometer.init();
magnetometer.enable();
local reading = magnetometer.readAxes();

```

# License

The LIS3MDL class is licensed under the [MIT License](./LICENSE).
