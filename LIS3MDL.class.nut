// Copyright (c) 2015 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

class LIS3MDL {

    static VERSION = [2,0,0];

    // External constants
    static AXIS_X = 0x80;
    static AXIS_Y = 0x40;
    static AXIS_Z = 0x20;
    // Note that if INTERRUPT_ISACTIVEHIGH is used to generate a wake signal, significant power may be wasted.  See README for details.
    static INTERRUPT_ISACTIVEHIGH = 0x04;
    static INTERRUPT_DONTLATCH = 0x02;
    static DATA_RATE_FAST = -1;
    static CONTINUOUS_MODE = 0x00;
    static ONE_SHOT_MODE = 0x01;
    static SHUT_DOWN_MODE = 0x11;

    // Internal constants
    static REG_ADDR_OUT_X_L = 0x28;
    static REG_ADDR_OUT_Y_L = 0x2A;
    static REG_ADDR_OUT_Z_L = 0x2C;
    static REG_CTL_1 = 0x20;
    static REG_CTL_2 = 0x21;
    static REG_CTL_3 = 0x22;
    static REG_CTL_4 = 0x23;
    static REG_STATUS = 0x27;
    static REG_INT_CFG = 0x30;
    static REG_INT_SRC = 0x31;
    static REG_INT_THS_L = 0x32;
    static REG_INT_THS_H = 0x33;
    static SENSITIVITY_OF_MIN_SCALE = 27368.0; // = (4 gauss scale) * (6842 LSB/gauss at 4 gauss scale)

    _i2c = null;
    _address = null;
    _scale = null;

    function constructor(i2c, address=0x1C) {
        _i2c = i2c;
        _address = address;

        init();
    }

    function init() {
        // Update the cached scale so that we can convert readings to gauss
        local reg2 = _readRegister(REG_CTL_2);
        if(reg2 == 0x00) _scale = 4;
        if(reg2 == 0x20) _scale = 8;
        if(reg2 == 0x40) _scale = 12;
        if(reg2 == 0x60) _scale = 16;
    }

    function setPerformance(performanceRating) {
        local bitsXY = performanceRating << 5;
        _writeRegister(REG_CTL_1, bitsXY, 0x60);

        local bitsZ = performanceRating << 2;
        _writeRegister(REG_CTL_4, bitsZ, 0x0C);
    }

    function setDataRate(dataRate) {
        local bits = 0x00;
        if (dataRate == DATA_RATE_FAST) {
            bits = 0x02;
        } else {
            // Cap the data rate before feeding it to equation
            if (dataRate > 80) {
                dataRate = 80;
            }
            // This is the equation used to convert data rates to the proper bitfield
            bits = (math.log(dataRate / 0.625) / math.log(2)).tointeger() << 2;
            // Calculate actual rate used
            dataRate = 0.625 * math.pow(2, (bits >> 2));
        }

        _writeRegister(REG_CTL_1, bits, 0x1E);
        return dataRate
    }

    function setConversionMode(mode) {
        _writeRegister(REG_CTL_3, mode, 0x03);
    }

    function setScale(scale) {
        _scale = scale.tointeger();

        // Cap the scale before sending it to equation
        if (_scale < 4) {
            _scale = 4;
        }

        if (_scale > 16) {
            _scale = 16;
        }

        local bits = ((_scale / 4) - 1) << 5;
        _writeRegister(REG_CTL_2, bits, 0x60);

        // Set locally stored scale to actual rate used
        _scale = ((bits >> 5) + 1) * 4;

        // Return actual rate used
        return _scale;
    }

    function setLowPower(state) {
        local bits = state ? 0x20 : 0x00;
        _writeRegister(REG_CTL_3, bits, 0x20);
    }

    function configureInterrupt(isEnabled, threshold=0, options=0) {
        // First configure interrupt threshold
        local scaledThreshold = (threshold * SENSITIVITY_OF_MIN_SCALE / _scale).tointeger();
        local thresholdLow = scaledThreshold & 0xFF;
        local thresholdHigh = (scaledThreshold >> 8) & 0x7F;
        _writeRegister(REG_INT_THS_L, thresholdLow);
        _writeRegister(REG_INT_THS_H, thresholdHigh);

        // Then enable/disable and configure the interrupt
        local interruptBits = 0x00;
        if (isEnabled) {
            // Mix in options, but flip DONTLATCH bit
            interruptBits = (options | 0x01) ^ INTERRUPT_DONTLATCH;
        }

        _writeRegister(REG_INT_CFG, interruptBits);

        // Give the device time to start up - otherwise issues with interrupts occur
        imp.sleep(0.01);
    }

    function reset() {
        _writeRegister(REG_CTL_2, 0x04, 0x04);
        init();
    }

    function readAxes(callback=null) {
        if (callback == null) {
            return {
                "x" : _readAxisAtAddress(REG_ADDR_OUT_X_L),
                "y" : _readAxisAtAddress(REG_ADDR_OUT_Y_L),
                "z" : _readAxisAtAddress(REG_ADDR_OUT_Z_L)
            };
        } else {
            // If a callback was specified, make sure this function call won't block
            imp.wakeup(0, function() {
                local result = readAxes();
                callback(result);
            }.bindenv(this));
        }
    }

    function readStatus() {
        local statusByte = _readRegister(REG_STATUS);

        local statusTable = {
            "ZYXOR" : statusByte & 0x80 ? true : false,
            "ZOR"   : statusByte & 0x40 ? true : false,
            "YOR"   : statusByte & 0x20 ? true : false,
            "XOR"   : statusByte & 0x10 ? true : false,
            "ZYXDA" : statusByte & 0x08 ? true : false,
            "ZDA"   : statusByte & 0x04 ? true : false,
            "YDA"   : statusByte & 0x02 ? true : false,
            "XDA"   : statusByte & 0x01 ? true : false
        };

        return statusTable;
    }

    function readInterruptStatus() {
        local interruptByte = _readRegister(REG_INT_SRC);

        local statusTable = {
            "x_positive" : interruptByte & 0x80 ? true : false,
            "y_positive" : interruptByte & 0x40 ? true : false,
            "z_positive" : interruptByte & 0x20 ? true : false,
            "x_negative" : interruptByte & 0x10 ? true : false,
            "y_negative" : interruptByte & 0x08 ? true : false,
            "z_negative" : interruptByte & 0x04 ? true : false,
            "overflow"   : interruptByte & 0x02 ? true : false,
            "interrupt"  : interruptByte & 0x01 ? true : false
        };

        return statusTable;
    }

    // -------------------- PRIVATE METHODS -------------------- //

    // Reads and returns 1 byte from the specified register
    // If twoBytes is true, reads 2 bytes from the specified register and the one immediately following it and returns them as a 16-bit int
    function _readRegister(register, twoBytes=false) {
        local value = _i2c.read(_address, register.tochar(), twoBytes ? 2 : 1);
        if (value == null) {
            throw "I2C read error: " + _i2c.readerror();
        } else if (twoBytes) {
            return (value[1] << 8) | value[0];
        } else {
            return value[0];
        }
    }

    // Writes a 1-byte value to a register.
    // If mask is specified, only the bits masked with 1s will be sent to the register
    function _writeRegister(register, value, mask=0xFF) {
        local valueToWrite = value;
        if (mask != 0xFF) {
            valueToWrite = (_readRegister(register) & ~mask) | (value & mask);
        }
        local result = _i2c.write(_address, format("%c%c", register, valueToWrite));
        if (result) {
            throw "I2C write error: " + result;
        }
    }

    // Parses and scales (into gauss) the axis reading from the specified axis register
    function _readAxisAtAddress(register) {
        local raw = _readRegister(register, 2);
        local signed = _parseTwosComplement(raw);
        local scaled = signed * _scale / SENSITIVITY_OF_MIN_SCALE;
        return scaled;
    }

    // Takes an unsigned 16-bit int representing a 2C number
    // Returns the signed number it represents
    static function _parseTwosComplement(unsignedValue) {
        if (unsignedValue & 0x8000) {
            local signedValue = (~unsignedValue + 1) & 0xFFFF;
            return -1 * signedValue;
        } else {
            return unsignedValue;
        }
    }
}
