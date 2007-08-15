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


import std.string;
import std.stdio;
import std.c.time;
import std.socketstream;

import general;
import dmxnode;
import dmxdevbus;
import dmxfunction;

enum E_SecurityLevel {SL_Unknown, SL_Guest, SL_User, SL_Admin};

const char [] psuccess = "ACK";
const char [] perror = "ERR";

class CH_Info : CommandHandler {
	this(DMXp dmxp, E_SecurityLevel seclevel) {
		super(dmxp, seclevel);
	}
	
	this(DMXpClient dmxpc) {
		super(dmxpc);
	}
	
	void init() {
		description = "prints informations about the DMXNode and its subsystems.";
		command = "info";
	}
	
	char [] execute(char []key, char [] cmd) {
		int i,active, inactive;
		char []result = "\n";
		
		result ~= std.string.format("DMXNode %s Version %d - %s\n", dmxp.node.name, dmxp.node.node_version, dmxp.node.description);
		result ~= std.string.format("DMXp Version %d\n", dmxp.dmxp_version);
		if ((cast(DMXpServer) dmxp).getSecLevelOfSession(key) >= E_SecurityLevel.SL_Guest)
			//result ~= std.string.format("Active Devices (inactive): %d (%d)\n", active, inactive);
			result ~= std.string.format("Devices: %d \n", active);
		
		result ~= "Your level: ";
		switch (dmxps.getSecLevelOfSession(key)) {
			case E_SecurityLevel.SL_Guest: result ~= "guest\n"; break;
			case E_SecurityLevel.SL_User: result ~= "user\n"; break;
			case E_SecurityLevel.SL_Admin: result ~= "admin\n"; break;
			default:	result ~= "unknown\n"; break;
		}
		
		
		return dmxp.success_prefix~result;
	}
	
	char [][char[]] send () {
		RetMessage res;
		char [][]lines;
		char [][]rex;
		char [][char[]] result;
		
		res = dmxpc.send_command(this.command~"\n");
		lines = res.all().split("\n");
		
		foreach (line;lines) {
			rex = re_search(`^DMXNode\s(\S+)\sVersion\s(\S+)\s-\s(.+)`, line);
			if (rex) {
				result["node_name"] = rex[1];
				result["node_version"] = rex[2];
				result["node_description"] = rex[3];
			}
			rex = re_search(`^DMXp\sVersion\s(\S+)`, line);
			if (rex) {
				result["dmxp_version"] = rex[1];
			}
			rex = re_search(`^Devices:\s(\S+)`, line);
			if (rex) {
				result["devices"] = rex[1];
			}
			rex = re_search(`^Your\slevel:\s(\S+)`, line);
			if (rex) {
				result["level"] = rex[1];
			}
		}

		return result;
	}
	
}

class CH_ListDevices : CommandHandler {
	this(DMXp dmxp, E_SecurityLevel seclevel) {
		super(dmxp, seclevel);
	}
	
	this(DMXpClient dmxpc) {
		super(dmxpc);
	}
	
	void init() {
		command = "list_devices";
		description = std.string.format("lists detailed informations of one or all devices. Usage: %s [<devicename>]", command);
	}
	
	char [] execute(char [] cmd) {
		char [][]arg;
		char []result = "\n";
		
		arg = re_search(`^\s*(\S+)$`, cmd);
		if (arg) {
			if (arg[1] in dmxp.node.devices) {
				return dmxp.success_prefix~result~std.string.format("%s",dmxp.node.devices[arg[0]].get_info(1));
			} else
				return dmxp.error_prefix~std.string.format("%s not found", arg[0]);
		} else {
			result = "";
			foreach (dev; dmxp.node.devices) {
				result ~= std.string.format("\n%s",dev.get_info(1));
			}
			return dmxp.success_prefix~result;
		}
	}
	
	//DMXDeviceAbstract[char[]] send() {
	RetMessage send(DMXDeviceAbstract[char[]] *p_devices) {
		DMXDeviceAbstract[char[]] devices;
		RetMessage res;
		char [][]lines;
		char [][]rex;
		char [][]rex2;
		char []device;
		char []fct;

		//devices = *p_devices;

		res = dmxpc.send_command(this.command~"\n");

		if (res.ret) {
		
			lines = res.all().split("\n");
			
			foreach (line;lines) {
				rex = re_search(`^Device\s\'(\S+)\'\swith\sstatus:\s(.+)`, line);
				if (rex) {
					device = rex[1];
					devices[device] = new DMXDeviceAbstract(device);
					devices[device].fix_status = rex[2];
				}
				rex = re_search(`^\s-\sDesc:\s(.+)`, line);
				if (rex) {
					devices[device].description = rex[1];
				}
				rex = re_search(`^\s-\sType:\s(.+)`, line);
				if (rex) {
					devices[device].type = "v_"~rex[1];
				}
				
				rex = re_search(`^\s+\*\s\'(\S+)\'\s\((\S+)\)\sis\s(\S+),\s(.*)`, line);
				if (rex) {
					fct = rex[1];
					devices[device].functions[fct] = new DMXF_Virtual(fct, devices[device], dmxpc);
					devices[device].functions[fct].type = "v_"~rex[2];
					//active
					//final / connected
					
					(cast(DMXF_Virtual) devices[device].functions[fct]).vdestfct = fct;
					(cast(DMXF_Virtual) devices[device].functions[fct]).vdestdev = device;
					(cast(DMXF_Virtual) devices[device].functions[fct]).vdesthost = dmxpc.stream.socket().remoteAddress().toString();
						
					
					/*rex2 = re_search(`connected\swith\s\'(\S+)\'\sof\sdevice\s\'(\S+)\'`, rex[4]);
					if (rex2) {
						//destfct_args
						(cast(DMXF_Virtual) devices[device].functions[fct]).vdestfct = rex2[1];
						(cast(DMXF_Virtual) devices[device].functions[fct]).vdestdev = rex2[2];
						(cast(DMXF_Virtual) devices[device].functions[fct]).vdesthost = dmxpc.stream.socket().remoteAddress().toString();
						//destdev
					}*/
				}
			}
		}
		*p_devices = devices;
		return res;
	}
}

class CH_SetFunction : CommandHandler {
	this(DMXp dmxp, E_SecurityLevel seclevel) {
		super(dmxp, seclevel);
	}
	
	this(DMXpClient dmxpc) {
		super(dmxpc);
	}
	
	void init() {
		command = "setfct";
		description = std.string.format("calls a function of a device. Usage: %s <devicename> <function> <value>", command);
	}
	
	char [] execute(char [] cmd) {
		char [][] cmdarr;
		char []dev;
		char []fname;
		char []value;
		char []result = "\n";
		RetMessage i;
		DMXDeviceAbstract device;
		
		cmdarr = re_search(`^\s*(\S+)\s+(\S+)\s+(.+)$`, cmd);
		if (cmdarr) {
			dev = cmdarr[1];
			fname = cmdarr[2];
			value = cmdarr[3];
			
			if (dev in dmxp.node.devices) {
				device = dmxp.node.devices[dev];
				
				if (fname in device.functions) {
					i = device.functions[fname].set(value);
				
					if (i.ret > 0)
						return dmxp.success_prefix~i.all();
					else
						return dmxp.error_prefix~i.all();
				} else
					return dmxp.error_prefix~std.string.format("function %s in device %s not found.", fname, dev);
				
			} else
				return dmxp.error_prefix~std.string.format("device %s not found.",dev);
		}
		return dmxp.error_prefix~"wrong parameters.";
	}
	
	RetMessage send(char[] device, char[]fct, char[] value) {
		return dmxpc.send_command(this.command~" "~device~" "~fct~" "~value~"\n");
	}
}

class CH_AddFunction : CommandHandler {
	this(DMXp dmxp, E_SecurityLevel seclevel) {
		super(dmxp, seclevel);
	}
	
	this(DMXpClient dmxpc) {
		super(dmxpc);
	}
	
	void init() {
		command = "addfct";
		description = std.string.format("adds a function of a device. Usage: %s <devicename> <functionname> <functiontype>", command);
	}
	
	char [] execute(char [] cmd) {
		char [][] cmdarr;
		char []dev;
		char []fname;
		char []ftype;
		char []result = "\n";
		RetMessage i;
		DMXDeviceAbstract device;
		
		cmdarr = re_search(`^\s*(\S+)\s+(\S+)\s+(\S+)`, cmd);
		if (cmdarr) {
			dev = cmdarr[1];
			fname = cmdarr[2];
			ftype = cmdarr[3];
			
			if (dev in dmxp.node.devices) {
				device = dmxp.node.devices[dev];
				
				if ( (ftype in dmxp.node.fct_library) && (!(fname in device.functions)) ) {
					device.functions[fname] = dmxp.node.fct_library[ftype].create(fname, device, null);
				
					if (device.functions[fname])
						return dmxp.success_prefix~std.string.format("function '%s' added to '%s'", fname, dev);
				}
				return dmxp.error_prefix~"could not add function";
			} else
				return dmxp.error_prefix~std.string.format("device %s not found.",dev);
		}
		return dmxp.error_prefix~"wrong parameters.";
	}
	
	RetMessage send(char[] device, char[]fct, char[] fcttype) {
		return dmxpc.send_command(this.command~" "~device~" "~fct~" "~fcttype~"\n");
	}
}

class CH_RemFunction : CommandHandler {
	this(DMXp dmxp, E_SecurityLevel seclevel) {
		super(dmxp, seclevel);
	}
	
	this(DMXpClient dmxpc) {
		super(dmxpc);
	}
	
	void init() {
		command = "remfct";
		description = std.string.format("removes a function of a device. Usage: %s <devicename> <functionname>", command);
	}
	
	char [] execute(char [] cmd) {
		char [][] cmdarr;
		char []dev;
		char []fname;
		char []result = "\n";
		RetMessage i;
		DMXDeviceAbstract device;
		
		cmdarr = re_search(`^\s*(\S+)\s+(\S+)`, cmd);
		if (cmdarr) {
			dev = cmdarr[1];
			fname = cmdarr[2];
			
			if (dev in dmxp.node.devices) {
				device = dmxp.node.devices[dev];
				
				if (fname in device.functions) {
					device.functions.remove(fname);
					
					if (!(fname in device.functions))
						return dmxp.success_prefix~std.string.format("function '%s' removed from '%s'", fname, dev);
					else
						return dmxp.error_prefix~"could not remove function";
				} else
					return dmxp.error_prefix~std.string.format("no such function '%s'",fname);
			} else
				return dmxp.error_prefix~std.string.format("device %s not found.",dev);
		}
		return dmxp.error_prefix~"wrong parameters.";
	}
	
	RetMessage send(char[] device, char[]fct) {
		return dmxpc.send_command(this.command~" "~device~" "~fct~"\n");
	}
}

class CH_ModFunction : CommandHandler {
	this(DMXp dmxp, E_SecurityLevel seclevel) {
		super(dmxp, seclevel);
	}
	
	this(DMXpClient dmxpc) {
		super(dmxpc);
	}
	
	void init() {
		command = "modfct";
		description = std.string.format("modifies a function of a device. Usage: %s <devicename> <functionname> <command> [<values>]", command);
	}
	
	char [] execute(char [] cmd) {
		char [][] cmdarr;
		char []dev;
		char []fname;
		char []command;
		char []values;
		char []result = "\n";
		RetMessage i;
		DMXDeviceAbstract device;
		
		cmdarr = re_search(`^\s*(\S+)\s+(\S+)\s+(\S+)(.*)$`, cmd);
		if (cmdarr) {
			dev = cmdarr[1];
			fname = cmdarr[2];
			command = cmdarr[3];
			values = cmdarr[4];
			
			if (dev in dmxp.node.devices) {
				device = dmxp.node.devices[dev];
				
				if (fname in device.functions) {
					switch (command) {
						case "setdest":	cmdarr = re_search(`^\s*([^\:]+)\:([\S]+)\s*(.*)$`, values);
								if ((cmdarr[1] in dmxp.node.devices) && (cmdarr[2] in dmxp.node.devices[cmdarr[1]].functions) ) {
									device.functions[fname].destdev = dmxp.node.devices[cmdarr[1]];
									device.functions[fname].destfct = cmdarr[2];
									device.functions[fname].destfct_format = std.string.strip(cmdarr[3]);
								}
								return dmxp.success_prefix~"command was successfull.";
								
						case "setvar":	i = device.functions[fname].chvar(values);
								if (i.ret)
									return dmxp.success_prefix~i.all();
								else
									return dmxp.error_prefix~i.all();
								
						default:	return dmxp.error_prefix~"unknown function command: '"~command~"'";
					}
				} else
					return dmxp.error_prefix~std.string.format("no such function '%s'",fname);
			} else
				return dmxp.error_prefix~std.string.format("device %s not found.",dev);
		}
		return dmxp.error_prefix~"wrong parameters.";
	}
	
	RetMessage send(char[] device, char[]fct, char[] command, char[]parameters) {
		return dmxpc.send_command(this.command~" "~device~" "~fct~" "~command~" "~parameters~"\n");
	}
}

class CH_GetFunction : CommandHandler {
	this(DMXp dmxp, E_SecurityLevel seclevel) {
		super(dmxp, seclevel);
	}
	
	this(DMXpClient dmxpc) {
		super(dmxpc);
	}
	
	void init() {
		command = "getfct";
		description = std.string.format("returns the current value of a function. Usage: %s <devicename> <function> [<value>]", command);
	}
	
	char [] execute(char [] cmd) {
		char [][] cmdarr;
		char []dev;
		char []fname;
		char []values;
		char []result = "\n";
		RetMessage i;
		DMXDeviceAbstract device;
		
		cmdarr = re_search(`^\s*(\S+)\s+(\S+)\s*(.*)`, cmd);
		if (cmdarr) {
			dev = cmdarr[1];
			fname = cmdarr[2];
			values = cmdarr[3];
			
			if (dev in dmxp.node.devices) {
				device = dmxp.node.devices[dev];
				if (fname in device.functions) {
					i = device.functions[fname].get(values);
				
					if (i.ret > 0)
						return dmxp.success_prefix~i.all();
					else
						return dmxp.error_prefix~i.all();
				} else
					return dmxp.error_prefix~std.string.format("function %s in device %s not found.", fname, dev);
			} else
				return dmxp.error_prefix~std.string.format("device %s not found.",dev);
		}
		return dmxp.error_prefix~"wrong parameters.";
	}
	
	RetMessage send(char[] device, char[]fct) {
		return dmxpc.send_command(this.command~" "~device~" "~fct~" \n");
	}
}

class CH_AddDevice : CommandHandler {
	this(DMXp dmxp, E_SecurityLevel seclevel) {
		super(dmxp, seclevel);
	}
	
	this(DMXpClient dmxpc) {
		super(dmxpc);
	}
	
	void init() {
		command = "adddev";
		description = std.string.format("adds a device. Usage: %s <devicename>", command);
	}
	
	char [] execute(char [] cmd) {
		char [][] cmdarr;
		char []dev;
		char []fname;
		char []ftype;
		char []result = "\n";
		RetMessage i;
		DMXDeviceAbstract device;
		
		cmdarr = re_search(`^\s*(\S+)`, cmd);
		if (cmdarr) {
			dev = cmdarr[1];
			if (!(dev in dmxp.node.devices)) {
				dmxp.node.devices[dev] = new DMXDeviceAbstract(dev);
				return dmxp.success_prefix~"";
			} else
				return dmxp.error_prefix~" a device with this name already exists.";
		}
		return dmxp.error_prefix~"wrong parameters.";
	}
	
	RetMessage send(char[] device) {
		return dmxpc.send_command(this.command~" "~device~"\n");
	}
}

class CH_RemDevice : CommandHandler {
	this(DMXp dmxp, E_SecurityLevel seclevel) {
		super(dmxp, seclevel);
	}
	
	this(DMXpClient dmxpc) {
		super(dmxpc);
	}
	
	void init() {
		command = "remdev";
		description = std.string.format("removes a device. Usage: %s <devicename>", command);
	}
	
	char [] execute(char [] cmd) {
		char [][] cmdarr;
		char []dev;
		char []fname;
		char []result = "\n";
		RetMessage i;
		DMXDeviceAbstract device;
		
		cmdarr = re_search(`^\s*(\S+)`, cmd);
		if (cmdarr) {
			dev = cmdarr[1];
			
			if (dev in dmxp.node.devices) {
				device = dmxp.node.devices[dev];
				dmxp.node.devices.remove(dev);
				delete device;
				return dmxp.success_prefix~" '"~dev~"' removed.";
			} else
				return dmxp.error_prefix~std.string.format("device %s not found.",dev);
		}
		return dmxp.error_prefix~"wrong parameters.";
	}
	
	RetMessage send(char[] device) {
		return dmxpc.send_command(this.command~" "~device~"\n");
	}
}

class CH_ModDevice : CommandHandler {
	this(DMXp dmxp, E_SecurityLevel seclevel) {
		super(dmxp, seclevel);
	}
	
	this(DMXpClient dmxpc) {
		super(dmxpc);
	}
	
	void init() {
		command = "moddev";
		description = std.string.format("modifies a device. Usage: %s <devicename> <command> [<values>]", command);
	}
	
	char [] execute(char [] cmd) {
		char [][] cmdarr;
		char []dev;
		char []command;
		char []values;
		char []result = "\n";
		RetMessage i;
		DMXDeviceAbstract device;
		
		cmdarr = re_search(`^\s*(\S+)\s+(\S+)(.*)$`, cmd);
		if (cmdarr) {
			dev = cmdarr[1];
			command = cmdarr[2];
			values = cmdarr[3];
			
			if (dev in dmxp.node.devices) {
				device = dmxp.node.devices[dev];
				
				switch (command) {
					case "setvar":	i = device.chvar(values);
							if (i.ret)
								return dmxp.success_prefix~i.all();
							else
								return dmxp.error_prefix~i.all();
							
					default:	return dmxp.error_prefix~"unknown function command: '"~command~"'";
				}
			} else
				return dmxp.error_prefix~std.string.format("device %s not found.",dev);
		}
		return dmxp.error_prefix~"wrong parameters.";
	}
	
	RetMessage send(char[] device, char[] command, char[]parameters) {
		return dmxpc.send_command(this.command~" "~device~" "~command~" "~parameters~"\n");
	}
}



class CH_Help : CommandHandler {
	this(DMXp dmxp, E_SecurityLevel seclevel) {
		super(dmxp, seclevel);
	}
	
	this(DMXpClient dmxpc) {
		super(dmxpc);
	}
	
	void init() {
		description = "shows the available commands. Usage: help [full]";
		command = "help";
	}
	
	char [] execute(char []key, char [] cmd) {
		char []result = "Available commands: (type 'help full' for a detailed list)\n";
		char [][]full;
		
		full = re_search(`^\s*(\S+)$`, cmd);
		
		if ((full) && (full[1] != "full"))
			result ~= "\n";
		
		foreach (handler; dmxp.handlers) {
			if ((cast(DMXpServer) dmxp).getSecLevelOfSession(key) >= handler.seclevel) {
				if ((full) && (full[1] == "full"))
					result ~= std.string.format("\n  %s - %s\n", handler.command, handler.description);
				else
					result ~= std.string.format("%s ", handler.command);
			}
		}
		
		if ((full) && (full[1] != "full"))
			result ~= "\n";
		return dmxp.success_prefix~result;
	}
	
	char [][char[]] send(bool full) {
		RetMessage res;
		char [][]lines;
		char [][]rex;
		char [][char[]]result;
		
		if (full) {
			res = dmxpc.send_command(this.command~" full\n");
			lines = res.all().split("\n");
			foreach (line; lines) {
				rex = re_search(`^\s*([\S]+)\s-\s(.+)`, line);
				if (rex) {
					result[rex[1]] = rex[2];
				}
			}
		} else {
			res = dmxpc.send_command(this.command~"\n");
			lines = res.all().split("\n");
			lines = lines[1].split(" ");
			foreach (line; lines) {
				result[line] = "";
			}
		}
		
		return result;
	}
}

class CH_Quit : CommandHandler {
	this(DMXp dmxp, E_SecurityLevel seclevel) {
		super(dmxp, seclevel);
	}
	
	this(DMXpClient dmxpc) {
		super(dmxpc);
	}
	
	void init() {
		description = "quits the program.";
		command = "quit";
	}
	
	char [] execute(char [] cmd) {
		dmxp.node.close = true;
		return dmxp.success_prefix~"closing.";
	}
	
	RetMessage send(SocketStream stream) {
		return dmxpc.send_command(this.command~"\n");
	}
}

class CH_Login : CommandHandler {
	this(DMXp dmxp, E_SecurityLevel seclevel) {
		super(dmxp, seclevel);
	}
	
	this(DMXpClient dmxpc) {
		super(dmxpc);
	}
	
	void init() {
		description = "Usage: login <level> <password>";
		command = "login";
	}
	
	char [] execute(char []key, char [] cmd) {
		char []level;
		char []pw;
		char [][]buf;
		
		buf = re_search(`^\s*(\S+)\s+(\S+).*`, cmd);
		if (buf) {
			level = buf[1];
			pw = buf[2];
		//	if ( (level != null) && (pw != null) && (level in dmxp.node.config["passwords"]) ) {
			if (level in dmxp.node.config["passwords"]) {
				if (dmxp.node.config["passwords"][level] == pw) {
					switch (level) {
						case "guest":	dmxp.sessions[key].seclevel = E_SecurityLevel.SL_Guest; break;
						case "user":	dmxp.sessions[key].seclevel = E_SecurityLevel.SL_User; break;
						case "admin":	dmxp.sessions[key].seclevel = E_SecurityLevel.SL_Admin; break;
						default:	break;
					}
					return std.string.format(dmxp.success_prefix~"raise access level to '%s'",level);
				} else
					return dmxp.error_prefix~"wrong password.";
			} else
				return dmxp.error_prefix~"unknown level.";
		} else
			return dmxp.error_prefix~"wrong parameters.";
	}
	
	RetMessage send(char []level, char[]password) {
		return dmxpc.send_command("login "~level~" "~password~"\n");	
	}
}

/*! \brief root class for a command of the DMXp protocol

 */
class CommandHandler {
	DMXpClient dmxpc;
	DMXpServer dmxps;
	DMXp dmxp;
	char []description;
	char []command;
	E_SecurityLevel seclevel;
	
	// TODO change to DMXpServer
	this(DMXp dmxp, E_SecurityLevel min_seclevel) {
		this.dmxp = dmxp;
		this.dmxps = cast(DMXpServer) dmxp;
	/*	if (dmxp.classinfo.name == "dmxp.DMXpServer")
			this.dmxps = cast(DMXpServer) dmxp;
		else
			this.dmxpc = cast(DMXpClient) dmxp;*/
		init();
		this.seclevel = min_seclevel;
	}
	
	this(DMXpClient dmxpc) {
		this.dmxpc = dmxpc;
		init();
	}
	
	void init() {
	}
	
	char [] execute(char []cmd) {
		return "";
	}
	
	char [] execute(char []key, char []cmd) {
		return execute(cmd);
	}
	
	RetMessage check(char [] cmd) {
		char [][] buf;
		if ((buf = re_search(`^[\s]*(`~command~`)`,cmd)) != null) {
			return new RetMessage(1);
			//execute(key, buf[2]);
		}
		return new RetMessage(0);
	}
}

/*! \brief small class that represents a session on the server-side

 */
class DMXpSession {
	char []key;
	E_SecurityLevel seclevel;
	
	this(char []key) {
		this.key = key;
		seclevel = E_SecurityLevel.SL_Unknown;
	}
}

/*! \brief root class for DMXp communication

 */
class DMXp {
	DMXNode node;
	CommandHandler [char[]]handlers;
	int dmxp_version;
	DMXpSession [char[]] sessions;
	char [] success_prefix;
	char [] error_prefix;
	
	this(DMXNode node) {
		this.node = node;
		this.dmxp_version = 0;
		success_prefix = psuccess~": ";
		error_prefix = perror~": ";
	}
	
	this() {
		this.dmxp_version = 0;
		success_prefix = psuccess~": ";
		error_prefix = perror~": ";
	}
	
	~this() {
		foreach(handler; handlers)
			delete handler;
		foreach(session; sessions)
			delete session;
	}
}

/*! \brief implements the server side of the DMXp protocol

 */
class DMXpServer : DMXp {
	this(DMXNode node) {
		super(node);
		
		handlers["Quit"] = new CH_Quit(this, E_SecurityLevel.SL_Admin);
		handlers["Help"] = new CH_Help(this, E_SecurityLevel.SL_Unknown);
		handlers["Info"] = new CH_Info(this, E_SecurityLevel.SL_Unknown);
		handlers["Login"] = new CH_Login(this, E_SecurityLevel.SL_Unknown);
		handlers["ListDevices"] = new CH_ListDevices(this, E_SecurityLevel.SL_Guest);
		handlers["SetFunction"] = new CH_SetFunction(this, E_SecurityLevel.SL_User);
		handlers["GetFunction"] = new CH_GetFunction(this, E_SecurityLevel.SL_User);
		handlers["AddFunction"] = new CH_AddFunction(this, E_SecurityLevel.SL_Admin);
		handlers["RemFunction"] = new CH_RemFunction(this, E_SecurityLevel.SL_Admin);
		handlers["ModFunction"] = new CH_ModFunction(this, E_SecurityLevel.SL_Admin);
		
		handlers["AddDevice"] = new CH_AddDevice(this, E_SecurityLevel.SL_Admin);
		handlers["RemDevice"] = new CH_RemDevice(this, E_SecurityLevel.SL_Admin);
		handlers["ModDevice"] = new CH_ModDevice(this, E_SecurityLevel.SL_Admin);
	}
	
	int registerSession(char []key) {
		printd(E_MT.MT_DEBUG, std.string.format("Registering session '%s'.\n",key));
		if (key in sessions) {
			return 0;
		} else {
			sessions[key] = new DMXpSession(key);
			return 1;
		}
	}
	
	E_SecurityLevel getSecLevelOfSession(char []key) {
		if (key in sessions) {
			return sessions[key].seclevel;
		} else {
			return E_SecurityLevel.SL_Unknown;
		}	
	}
	
	int closeSession(char []key) {
		printd(E_MT.MT_DEBUG, std.string.format("Closing session '%s'.\n",key));
		sessions.remove(key);
		return 1;
	}

	char[] command(char []key, char[] cmd) {
		char []buf;
		char [][]res;
		int result = 0;
		
		cmd = cmd.strip();
		
		printd(E_MT.MT_DEBUG, std.string.format("Reveiving command '%s'.\n",cmd));
		
		synchronized {
			if (key in sessions) {
				result = 0;
				foreach (handler; handlers) {
					if (handler.check(cmd).ret) {
						if (getSecLevelOfSession(key) >= handler.seclevel) {
							if ((res = re_search(`^[\s]*`~handler.command~`[\s]*(.*)$`,cmd)) != null) {
								buf = handler.execute(key, res[1]);
								result = 1;
								break;	
							}
						} else
							result = 2;
					}
					
				}
				
				switch (result) {
					case 2: return error_prefix ~ "you are not allowed to execute this command.";
					case 1:	return buf;
					default:return error_prefix ~ "unknown command. Try 'help full' for a detailed list of available commands.";
				}
			} else {
				printd(E_MT.MT_ERROR, std.string.format("unknown session '%s'.\n",key));
				return error_prefix ~ "unknown session.";
			}
			}
		return "";
	}
	
	void printd(E_MT messagetype, char[] message) { general.printd(messagetype, "DMXp: " ~ message); }
}

/*! \brief implements the client side of the DMXp protocol

 */
class DMXpClient : DMXp {
	DMXNode node;
	CommandHandler [char []]handlers;
	int dmxp_version;
	DMXpSession [char[]] sessions;
	char [] success_prefix;
	char [] error_prefix;
	SocketStream stream;
	
	CH_Quit h_Quit;
	CH_Help h_Help;
	CH_Info h_Info;
	CH_Login h_Login;
	CH_ListDevices h_ListDevices;
	CH_SetFunction h_SetFunction;
	CH_GetFunction h_GetFunction;
	CH_AddFunction h_AddFunction;
	CH_RemFunction h_RemFunction;
	CH_ModFunction h_ModFunction;
	
	CH_AddDevice h_AddDevice;
	CH_RemDevice h_RemDevice;
	CH_ModDevice h_ModDevice;
	
	this(SocketStream stream) {
		super();
		
		this.stream = stream;
		
		h_Quit = new CH_Quit(this);
		h_Help = new CH_Help(this);
		h_Info = new CH_Info(this);
		h_Login = new CH_Login(this);
		h_ListDevices = new CH_ListDevices(this);
		h_SetFunction = new CH_SetFunction(this);
		h_GetFunction = new CH_GetFunction(this);
		h_AddFunction = new CH_AddFunction(this);
		h_RemFunction = new CH_RemFunction(this);
		h_ModFunction = new CH_ModFunction(this);
		
		h_AddDevice = new CH_AddDevice(this);
		h_RemDevice = new CH_RemDevice(this);
		h_ModDevice = new CH_ModDevice(this);
	}
	
	RetMessage quit() {
		return h_Quit.send(stream);
	}
	
	char [][char[]] help(bool full) {
		return h_Help.send(full);
	}
	
	char [][char[]] info() {
		return h_Info.send();
	}
	
	RetMessage login(char []level, char[] password) {
		return h_Login.send(level, password);
	}
	
	RetMessage list_devices(DMXDeviceAbstract [char[]] *devices) {
		return h_ListDevices.send(devices);
	}
	
	
	RetMessage setfunction(char []device, char[]fct, char[]value) {
		return h_SetFunction.send(device, fct, value);
	}
	
	RetMessage getfunction(char []device, char[]fct) {
		return h_GetFunction.send(device, fct);
	}
	
	RetMessage addfunction(char []device, char[]fct, char []fcttype) {
		return h_AddFunction.send(device, fct, fcttype);
	}
	
	RetMessage modfunction(char []device, char[]fct, char []command, char[]parameters) {
		return h_ModFunction.send(device, fct, command, parameters);
	}
	
	RetMessage remfunction(char []device, char[]fct) {
		return h_RemFunction.send(device, fct);
	}
	
	RetMessage prepare_result(char []result) {
		char [][] res;
		char []desc;
	
		res = re_search(`^\s*(ACK|ERR).*`, result);
		
		if (res) {
			if (result.length > 5)
				desc = result[5..result.length].strip();
			if (res[1] == "ACK")
				return new RetMessage(1, desc);
			else
				return new RetMessage(0, desc);
		}
		
		return new RetMessage(0, "malformed response: "~result);
	}
	
	RetMessage send_command(char []cmd) {
		char[] line;
		char[] lastline;
		char[] result;
		
		stream.writeString(cmd);
		lastline = " ";
		while (! stream.eof()) {
			line = stream.readLine();
			if ((line=="") && (lastline == "")) break;
			lastline = line;
			result ~= line~"\n";
		}
		return prepare_result(result);
	}
}
