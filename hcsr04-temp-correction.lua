-- HC-SR04

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
--  2) dofile("hcsr04.lua")
--  3) h = HCSR04(1, 2, 25, 3)
--  4) h.measure()

-- for continuous measuring, just do self.continuous = true

-- trig_pin: nodemcu pin (0-8)
-- echo_pin: nodemcu pin (0-8)
-- temp_pin: nodemcu pin (0-8) dht22 
-- max_distance:   in meters, this is used to calculate the maxium time
--                 for an echo response
-- avg_readings:   how many readings to be taken and averaged
-- measure_available_cb: callback function to be called there is a measure
--                 available
--  The measure_available_cb receives the following parameters:
-- (distance, readings, clean_distance, clean_readings)
-- distance is a simple avg of all the "readings"
-- clean_distance is an avg of readings without the "strange values" detected
-- using standard deviation.
function HCSR04(trig_pin, echo_pin, temp_pin, max_distance, avg_readings, measure_available_cb)

	local self = {}

	-- public fields

	-- continuous measuring
	self.continuous = false
	-- how many readings per measure
	self.avg_readings = math.max(1, avg_readings)
	-- measure done callback function
	self.measure_available_cb = nil

	-- change this if you are already using the timer id 0
	local trigger_timer_id = 0

	-- private fields
	local echo_start = 0
	local echo_stop = 0
	local distance = 0
	local readings = {}
	local clean_readings = {}
	local clean_distance = 0

	-- trig duration in microseconds (minimun is 10, see HC-SR04 documentation)
	local trigger_duration = 15

	-- speed of sound at 20°
	local speed_of_sound = 343.46

	-- maximum distance that will be measured
	local maximum_distance = math.max(25, max_distance)

	-- minimum reading interval with 20% of margin
	local reading_interval = math.ceil(((maximum_distance * 2 / speed_of_sound * 1000) + trigger_duration) * 1.2)

	-- start a measure cycle
	function self.measure()
		readings = {}
		tmr.start(trigger_timer_id)
	end

	-- called when measure is done
	function self.measure_available()

		if measure_available_cb then
			measure_available_cb(distance, #readings, clean_distance, #clean_readings)
		else
			print(string.format("%.3f", distance).." "..#readings.." "..string.format("%.3f", clean_distance).." "..#clean_readings)
		end

		if self.continuous then
			node.task.post(self.measure)
		end
	end

	-- uses standard deviation to remove strange readings
	function self.clean_readings()
		local mean = distance
		local diffs = {}
		local s = 0

		for k,v in pairs(readings) do
			local diff = v - mean
			diffs[k] = diff
			s = s + (diff * diff)
		end

		s = math.sqrt(s / 2)

		clean_distance = 0
		clean_readings = {}
		for k,v in pairs(diffs) do
			if v <= s then
				table.insert(clean_readings, readings[k])
				clean_distance = clean_distance + readings[k]
			end
		end

		clean_distance = clean_distance / #clean_readings
	end


	function self.get_temperature()
		status, temp, humi, temp_dec, humi_dec = dht.read(pin)
		if status == dht.OK then
			return temp		
		elseif status == dht.ERROR_CHECKSUM then
			print( "DHT Checksum error." )
		elseif status == dht.ERROR_TIMEOUT then
			print( "DHT timed out." )
		end


	function self.set_velocity_of_sound(temp)
		--- 331.5 velocity at 0 degresse
		--- 0.604 is the factor 
		speed_of_sound = (temp * 0.604) + 331.50

	-- distance calculation, called by the echo_callback function on falling edge.
	function self.calculate()

		-- echo time (or high level time) in seconds
		local echo_time = (echo_stop - echo_start) / 1000000
		local temp = self.get_temperature()
		self.set_velocity_of_sound(temp)

		-- got a valid reading
		if echo_time > 0 then
			-- distance = echo time (or high level time) in seconds * velocity of sound (340M/S) / 2
			local dist = echo_time * speed_of_sound / 2
			table.insert(readings, dist)
		end

		-- got all readings
		if #readings >= self.avg_readings then
			tmr.stop(trigger_timer_id)

			-- calculate the average of the readings
			distance = 0
			for k,v in pairs(readings) do
				distance = distance + v
			end
			distance = distance / #readings
			
			self.clean_readings()

			if (distance >= 0) then
				node.task.post(self.measure_available)
			end

		end
	end

	-- echo callback function called on both rising and falling edges
	function self.echo_callback(level)
		if level == 1 then
			-- rising edge (low to high)
			echo_start = tmr.now()
		else
			-- falling edge (high to low)
			echo_stop = tmr.now()
			self.calculate()
		end
	end

	-- send trigger signal
	function self.trigger()
		gpio.write(trig_pin, gpio.HIGH)
		tmr.delay(trigger_duration)
		gpio.write(trig_pin, gpio.LOW)
	end

	-- configure pins
	gpio.mode(trig_pin, gpio.OUTPUT)
	gpio.mode(echo_pin, gpio.INT)

	-- trigger timer
	tmr.register(trigger_timer_id, reading_interval, tmr.ALARM_AUTO, self.trigger)

	-- set callback function to be called both on rising and falling edges
	gpio.trig(echo_pin, "both", self.echo_callback)

	return self
end
