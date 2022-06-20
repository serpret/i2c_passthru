#i2c_passthru
i2c_passthru is a module that allows connecting i2c busses using an FPGA / CPLD / or other non-bidrectional reprogrammable logic device.

i2c allows bidirectional control of the SCL (clock stretching) and the SDA lines.  This makes connecting 2 i2c busses together through an FPGA device not trivial. 

The top level RTL file is in ./RTL/i2c_passthru.v
The top level TB file and helper libraries for the above is in 

./TB/TB_i2c_passthru/TB_simple_i2c_passthru.v
./TB/TB_i2c_passthru/TB_simple_i2c_passthru_drivers.v
./TB/TB_i2c_passthru/TB_i2c_passthru_monitors.v

individual testbenches for submodules are located in the below directory

./TB/TB_i2c_passthru/

