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


import std.thread;
import std.string;
import std.stdio;

import readline;
import general;
import pluginclasses;
import dmxp;
import dmxnode;
import libini;


/*! \brief provides readline commandline interface

 */
class Readline_Input : Input_Plugin {
	DMXpServer dmxp;
	DMXNode node;
	char []session;
	Thread t1;
	
	this(char[] name) {
		super(name);
	}
	
	~this() {
		dmxp.closeSession(session);
		rl_cleanup_after_signal();
	}
	
	RetMessage init(DMXNode node) {
		printd(E_MT.MT_DEBUG,std.string.format("Init plugin.\n"));
		
		this.node = node;
		dmxp = node.dmxp;
		
		return new RetMessage(1);
	}
	
	RetMessage start() {
		printd(E_MT.MT_DEBUG,std.string.format("starting ui...\n"));

		t1 = new Thread(&start_thread, cast(void*)this, 0);
		t1.start();
		//while(t1.getState() == std.thread.Thread.TS.RUNNING)
		//	Thread.yield (); 
		
		return new RetMessage(1);
	}
	
	void loop() {
		char [] buf = "";
		
		session = this.name ~ "stdin";
		dmxp.registerSession(session);
		dmxp.sessions[session].seclevel = E_SecurityLevel.SL_Admin;
		
		rl_bind_key ('\t', &rl_insert);
		
		while (!node.close) {
			buf = rl_readline("> ");
			if ( (buf) && (buf.strip() != "") ) {
				rl_add_history(buf);
				writef(dmxp.command(session,buf)~"\n");
			}
		}
	}
}

int start_thread(void *ptr) {
	Readline_Input ti = cast(Readline_Input) ptr;
	ti.loop();
	return 1;
}

// let the main process know what this plugin is good for
extern (C) char[] get_plugin_info() {
	ini_obj info;
	char [][char[]] general;
	
	general["version"] = "0";
	general["type"] = "input";
	general["name"] = "readline";
	info["general"] = general;
	return code_ini(info);
}

// init plugin - scan devices, etc
extern (C) Plugin get_plugin() {
	return new Readline_Input("readline");
}
