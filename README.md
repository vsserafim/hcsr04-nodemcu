# HC-SR04 Module with NodeMCU DevKit

These scripts are for demonstration only. Adapt them to your needs.
Each script is an independent program.

Those scripts were tested on NodeMCU Firmware 1.5.1.


IMPORTANT
---------

Note that the HC-SR04 needs at least 4.5V to work while NodeMCU runs on 3.3V.
As long as you connect your NodeMCU DevKit on a 5V USB supply, you can make
the connection like this: 

NodeMCU DevKit       HC-SR04
           Vin <---> Vcc
           Gnd <---> Gnd
            D1 <---> Trig
            D2 <---> Echo

Although this works, I would recomend the use of a __logic level converter__
just to be a little more safe.


Documentation
-------------

HC-SR04 datasheet: https://docs.google.com/document/d/1Y-yZnNhMYy7rwhAgyL_pfa39RsB-x2qR4vP8saG73rE