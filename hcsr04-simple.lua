-- HC-SR04 simple use example

-- Copyright 2016, Vinícius Serafim <vinicius@serafim.eti.br>

-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.

-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

-- How to:
--  1) upload this script to your nodemcu devkit
--  then, at the serial terminal:
--  2) dofile("hcsr04-simple.lua")
--  3) measure()

TRIG_PIN = 1
ECHO_PIN = 2

-- trig interval in microseconds (minimun is 10, see HC-SR04 documentation)
TRIG_INTERVAL = 15
-- maximum distance in meters
MAXIMUM_DISTANCE = 10
-- minimum reading interval with 20% of margin
READING_INTERVAL = math.ceil(((MAXIMUM_DISTANCE * 2 / 340 * 1000) + TRIG_INTERVAL) * 1.2)
-- number of readings to average
AVG_READINGS = 3
-- CONTINUOUS MEASURING
CONTINUOUS = false

-- initialize global variables
time_start = 0
time_stop = 0
distance = 0
readings = {}

-- start a measure cycle
function measure()
	readings = {}
	tmr.start(0)
end

-- called when measure is done
function done_measuring()
	print("Distance: "..string.format("%.3f", distance).." Readings: "..#readings)
	if CONTINUOUS then
		node.task.post(measure)
	end
end

-- distance calculation, called by the echo_callback function on falling edge.
function calculate()

	-- echo time (or high level time) in seconds
	local echo_time = (time_stop - time_start) / 1000000

	-- got a valid reading
	if echo_time > 0 then
		-- distance = echo time (or high level time) in seconds * velocity of sound (340M/S) / 2
		local distance = echo_time * 340 / 2
		table.insert(readings, distance)
	end

	-- got all readings
	if #readings >= AVG_READINGS then
		tmr.stop(0)

		-- calculate the average of the readings
		distance = 0
		for k,v in pairs(readings) do
			distance = distance + v
		end
		distance = distance / #readings
		
		node.task.post(done_measuring)
	end
end

-- echo callback function called on both rising and falling edges
function echo_callback(level)
	if level == 1 then
		-- rising edge (low to high)
		time_start = tmr.now()
	else
		-- falling edge (high to low)
		time_stop = tmr.now()
		calculate()
	end
end

-- send trigger signal
function trigger()
	gpio.write(TRIG_PIN, gpio.HIGH)
	tmr.delay(TRIG_INTERVAL)
	gpio.write(TRIG_PIN, gpio.LOW)
end

-- configure pins
gpio.mode(TRIG_PIN, gpio.OUTPUT)
gpio.mode(ECHO_PIN, gpio.INT)

-- trigger timer
tmr.register(0, READING_INTERVAL, tmr.ALARM_AUTO, trigger)

-- set callback function to be called both on rising and falling edges
gpio.trig(ECHO_PIN, "both", echo_callback)
