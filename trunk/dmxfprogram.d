/*  
 * Copyright (C) 2007 Mario Kicherer (http://empanyc.net)
 * 
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 * 
 */

import std.stdio;
import std.string;
import std.file;
import std.thread;
import std.math;

import general;
import pluginclasses;
import libini;
import dmxdevbus;
import dmxnode;
import dmxfunction;

/*! \brief root class for programs on functions
 
 */
class DMXF_Program : DMXFunction {
	int on;
	Thread t1;
	int terminate;

	this(char []name, DMXDeviceAbstract dev) {
		super(name, dev);
		type = "DMXF_Program";
		on = 0;
		terminate = 0;
		
		t1 = new Thread(&start_loop, cast(void*)this, 0);
	}
	
	~this() {
		if (t1) {
			terminate = 1;
			t1.wait();
			delete t1;
			t1 = null;
		}
	}
	
	static int start_loop(void *ptr) {
		DMXF_Program f = cast(DMXF_Program) ptr;
		return f.loop();
	}
	
	int loop() {
		while (!this.terminate) {
			sleep(1);
		}
		return 1;
	}
	
	RetMessage set(char[] value) {
		int val;
		if (value.isNumeric()) {
			val = cast(int)atoi(value);
			if (on != (val > 0)) {
				on = (val > 0);
				if (on) {
					if (t1.getState() == Thread.TS.INITIAL)
						t1.start();
					else
						t1.resume();
				} else
					t1.pause();
			}
			return new RetMessage(1);
		} else
			return new RetMessage(0, "value "~value~" is not numeric.");
	}
	
	RetMessage get(char[] value) {
		return new RetMessage(1, std.string.format("%s", this.on));
	}
}

class DMXFP_Sinus : DMXF_Program {
	int max;
	int min;
	float inc;
	uint timestep;
	

	static DMXFunction create(char []name, DMXDeviceAbstract dev, char[][char[]] options) {
		DMXFP_Sinus f = new DMXFP_Sinus(name, dev);
		if (options) {
			if ("min" in options)
				f.change_variable("min", options["min"]);
			if ("max" in options)
				f.change_variable("max", options["max"]);
			if ("inc" in options)
				f.change_variable("inc", options["inc"]);
			if ("timestep" in options)
				f.change_variable("timestep", options["timestep"]);
		}
		return f;
	}

	this(char []name, DMXDeviceAbstract dev) {
		super(name, dev);
		max = 255;
		min = 0;
		type = "sinus";
		inc = 0.05;
		timestep = 50000;
	}
	
	int loop() {
		float i = -PI;
		int j;
		
		while (!this.terminate) {
			j = cast(int) ((sin(i)+1)*(this.max-this.min))+this.min;
			this.post_set(std.string.format("%d", j));
			usleep(this.timestep);
			i = i + this.inc;
			if (i == PI)
				i = -PI;
		}
		return 1;
	}
	
	RetMessage change_variable(char []val1, char[] val2) {
		super.change_variable(val1, val2);
		
		switch(val1) {
			case "min" : min = cast(int) atoi(val2); break;
			case "max" : max = cast(int) atoi(val2); break;
			case "inc" : inc = cast(int) atoi(val2); break;
			case "timestep" : timestep = cast(uint) atoi(val2); break;
			default : return new RetMessage(0, "no such variable '"~val1~"'");
		}
		return new RetMessage(0, "variable '"~val1~"' set to '"~val2~"'");
	}
}

class DMXFP_Linear : DMXF_Program {
	int max;
	int min;
	float inc;
	uint timestep;
	

	static DMXFunction create(char []name, DMXDeviceAbstract dev, char[][char[]] options) {
		DMXFP_Linear f = new DMXFP_Linear(name, dev);
		if (options) {
			if ("min" in options)
				f.change_variable("min", options["min"]);
			if ("max" in options)
				f.change_variable("max", options["max"]);
			if ("inc" in options)
				f.change_variable("inc", options["inc"]);
			if ("timestep" in options)
				f.change_variable("timestep", options["timestep"]);
		}
		return f;
	}

	this(char []name, DMXDeviceAbstract dev) {
		super(name, dev);
		max = 255;
		min = 0;
		type = "linear";
		inc = 1;
		timestep = 50000;
	}
	
	int loop() {
		float i = -max;
		
		while (!this.terminate) {
			this.post_set(std.string.format("%d", cast(int) fabs(i)));
			usleep(this.timestep);
			i = i + this.inc;
			if (i >= max)
				i = -max;
			if ((i > -min) && (i < 0))
				i = min;
		}
		return 1;
	}
	
	RetMessage change_variable(char []val1, char[] val2) {
		super.change_variable(val1, val2);
		
		switch(val1) {
			case "min" : min = cast(int) atoi(val2); break;
			case "max" : max = cast(int) atoi(val2); break;
			case "inc" : inc = cast(int) atoi(val2); break;
			case "timestep" : timestep = cast(uint) atoi(val2); break;
			default : return new RetMessage(0, "no such variable '"~val1~"'");
		}
		return new RetMessage(0, "variable '"~val1~"' set to '"~val2~"'");
	}
}
