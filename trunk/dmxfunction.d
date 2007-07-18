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

import general;
import pluginclasses;
import libini;
import dmxdevbus;
import dmxnode;
import dmxp;

//enum DMXFunction_Type {DFT_Undefined, DFT_Bus, DFT_Range, DFT_Switch};

/*! \brief root class for functions
 
 */
class DMXFunction {
	char [] name;
	char [] description;
	DMXDeviceAbstract dev;
	char [] type;
	
	char []destfct;
	char []destfct_format;
	DMXDeviceAbstract destdev;
	int finalfct;
	
	RetMessage re;
	
	static DMXFunction create(char []name, DMXDeviceAbstract dev, char[][char[]] options) {
		printd(E_MT.MT_ERROR, "creating null fct\n");
		return null;
	}
	
	this (char []name, DMXDeviceAbstract dev) {
		this.name = name;
		this.dev = dev;
		//this.type = DMXFunction_Type.DFT_Undefined;
		this.type = "DMX_Function";
		this.destdev = null;
		this.destfct_format = "%s";
		finalfct = 0;
	}
	
	~this() {
	
	}
	
	int active() {
		if ( (destdev) && (destfct in destdev.functions) && (destdev.functions[destfct].active()) ) {
			return 1;
		} else
			return 0;
	}
	
	char[] get_info_helper(int verbose) {
		char []result;
		DMXFunction fct = this;
	
		result = std.string.format("'%s' (%s) is ", fct.name, fct.type);
		if (fct.active()) 
			result ~= "active";
		else
			result ~= "inactive";
			
		
		return result;
	}
	
	char[] get_info(int verbose) {
		char []result;
		DMXFunction fct = this;
		
		result = get_info_helper(verbose);
		
		if (finalfct)
			result ~= std.string.format(", final");
		else
			result ~= std.string.format("");
		
		if (fct.destfct == NO_DESTINATIONFCT) {
			if (!finalfct)
				result ~= std.string.format(", not connected.");
		} else {
			if (fct.destdev) {
				result ~= std.string.format(", connected with '%s'", fct.destfct);
				result ~= std.string.format(" of device '%s'", fct.destdev.name);
			} else {
				if (!finalfct)
					result ~= std.string.format(", not connected");
			}
		}
		return result~"\n";
	}
	
	RetMessage post_set(char []value) {
		if (destfct == NO_DESTINATIONFCT)
			return new RetMessage(-1, "No destination function defined for '"~name~"' of device '"~dev.name~"'.");
		
		if (!destdev)
			return new RetMessage(-1, "No destination device defined for '"~name~"' of device '"~dev.name~"'.");
		
		return destdev.functions[destfct].set(std.string.format(destfct_format, value));
	}
	
	RetMessage post_get(char []value) {
		if (destfct == NO_DESTINATIONFCT)
			return new RetMessage(-1, "No destination function defined for '"~name~"' of device '"~dev.name~"'.");
		
		if (!destdev)
			return new RetMessage(-1, "No destination device defined for '"~name~"' of device '"~dev.name~"'.");
		
		return destdev.functions[destfct].get(std.string.format(destfct_format, value));
	}
	
	RetMessage set(char[] value) {
		return new RetMessage(0, "No set function defined.");
	}
	
	RetMessage get(char[] value) {
		return new RetMessage(0, "No set function defined.");
	}
	
	RetMessage chvar(char []value) {
		char [][] val;
		
		val = re_search(`^\s*([^\=]+)\=(.+)$`, value);
		if (val) {
			return change_variable(val[1], val[2]);
		} else
			return new RetMessage(0,"wrong parameters, use variable=value.");
	}
	
	RetMessage change_variable(char []val1, char[] val2) {
		switch (val1) {
			case "name" : name = val2;
				break;
			case "desc" : description = val2;
				break;
			default : return new RetMessage(0, "no such variable '"~val1~"'");
		}
		return new RetMessage(1, "variable '"~val1~"' set to '"~val2~"'");
	}
}

/*! \brief virtual function

	virtual function that sends everything to a remote function
 */
class DMXF_Virtual : DMXFunction {
	char []vdestfct;
	char []vdestdev;
	char []vdesthost;
	DMXpClient dmxpc;

	static DMXFunction create(char []name, DMXDeviceAbstract dev, char[][char[]] options) {
		return new DMXF_Virtual(name, dev, null);
	}
	
	this (char []name, DMXDeviceAbstract dev, DMXpClient dmxpc) {
		super(name, dev);
		this.dmxpc = dmxpc;
		this.finalfct = 1;
		this.type = "virtual";
	}
	
	int active() {
		// TODO
		writef("FctVirtual Active TODO\n");
		return 1;
	}
	
	char[] get_info(int verbose) {
		char []result;
		result = get_info_helper(verbose);
		
		//result ~= std.string.format(", connected with '%s' of device '%s' on '%s'.\n", vdestfct, vdestdev, vdesthost);
		result ~= std.string.format(", connected with '%s'.\n", vdesthost);

		return result;
	}
	
	RetMessage set(char[] value) {
		return dmxpc.setfunction(vdestdev, vdestfct, value);
	}
	RetMessage get(char[] value) {
		return dmxpc.getfunction(vdestdev, vdestfct);
	}
}

/*! \brief function that represents a dmx bus

 */
class DMXF_Bus : DMXFunction {

	static DMXFunction create(char []name, DMXDeviceAbstract dev, char[][char[]] options) {
		return new DMXF_Bus(name, dev);
	}
	
	this (char []name, DMXDeviceAbstract dev) {
		super(name, dev);
		//type = DMXFunction_Type.DFT_Bus;
		type = "bus";
	}
	
	RetMessage get_channel(int channel) { return new RetMessage(0, "bus has no function get_channel.");}
	RetMessage set_channel(int channel, int value) { return new RetMessage(0, "bus has no function set_channel.");}
	
	RetMessage set(char[] value) {
		int channel, val;

		char [][] args = re_search(`\s*([\d]+)\s([\d]+)\s*`, value);
		if (args) {
			channel = cast(char) atoi(args[1]);
			val = cast(char) atoi(args[2]);
			return set_channel(channel, val);
		} else
			return new RetMessage(0, this.name~": incorrect argument");
	}
	
	RetMessage get(char [] channel) {
		try {
			return get_channel(cast(int) atoi(channel));
		}
		catch(Exception e)
		{
			printd(E_MT.MT_ERROR, e.msg);
			return new RetMessage(0, e.msg);
		}
	}
}

/*! \brief function that accepts values from 0 until 255

 */
class DMXF_Range : DMXFunction {
	int max;
	int min;

	static DMXFunction create(char []name, DMXDeviceAbstract dev, char[][char[]] options) {
		DMXF_Range f = new DMXF_Range(name, dev);
		if (options) {
			if ("min" in options)
				f.change_variable("min", options["min"]);
			if ("max" in options)
				f.change_variable("max", options["max"]);
		}
		return f;
	}

	this(char []name, DMXDeviceAbstract dev) {
		super(name, dev);
		max = 255;
		min = 0;
		//type = DMXFunction_Type.DFT_Range;
		type = "range";
	}
	
	RetMessage set_value(int value) {
		if ((min <= value) && (value <= max))
			return post_set(std.string.format("%d", value));
		else
			return new RetMessage(0,"value not in range.");
	}
	
	RetMessage set(char[] value) {
		if (value.isNumeric()) {
			return set_value(cast(int)atoi(value));
		} else
			return new RetMessage(0, "value "~value~" is not numeric.");
	}
	
	RetMessage get(char[] value) {
		return post_get(value);
	}
	
	RetMessage change_variable(char []val1, char[] val2) {
		super.change_variable(val1, val2);
		
		switch(val1) {
			case "min" : min = cast(int) atoi(val2); break;
			case "max" : max = cast(int) atoi(val2); break;
			default : return new RetMessage(0, "no such variable '"~val1~"'");
		}
		return new RetMessage(0, "variable '"~val1~"' set to '"~val2~"'");
	}
}

/*! \brief function that accepts values from 0 until 1

 */
class DMXF_Switch : DMXFunction {
	int state;
	int off;
	int on;
	
	static DMXFunction create(char []name, DMXDeviceAbstract dev, char[][char[]] options) {
		DMXF_Switch f = new DMXF_Switch(name, dev);
		if (options) {
			if ("off" in options)
				f.change_variable("off", options["off"]);
			if ("on" in options)
				f.change_variable("on", options["on"]);
		}
		return f;
	}
	
	this(char []name, DMXDeviceAbstract dev) {
		super(name, dev);
		//type = DMXFunction_Type.DFT_Switch;
		type = "switch";
	}
	
	RetMessage set_value(int state) {
		this.state = state;
		if (state > 0)
			return post_set(std.string.format("%d", on));
		else
			return post_set(std.string.format("%d", off));
	}
	
	RetMessage set(char[] value) {
		if (value.isNumeric()) {
			return set_value(cast(int)atoi(value));
		} else
			return new RetMessage(0, "value "~value~" is not numeric.");
	}
	
	RetMessage get(char[] value) {
		return post_get(value);
	}
	
	RetMessage change_variable(char []val1, char[] val2) {
		super.change_variable(val1, val2);
		
		switch(val1) {
			case "off" : off = cast(int) atoi(val2); break;
			case "on" : on = cast(int) atoi(val2); break;
			default : return new RetMessage(0, "no such variable '"~val1~"'");
		}
		return new RetMessage(0, "variable '"~val1~"' set to '"~val2~"'");
	}
}

