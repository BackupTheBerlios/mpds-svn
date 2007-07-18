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
import std.regexp;
import std.file;

import general;

typedef char [][char[]][char[]] ini_obj;

ini_obj read_ini(char [] ini) {
	ini_obj result;
	void [] data;
	
	if (exists(ini)) {
		data = read(ini);

		result = parse_ini(cast(char[]) data);
		
		return result;
	} else
		return null;
}

ini_obj parse_ini(char [] ini) {
	ini_obj result;
	char [] section="";
	char [] r;
	char [][] r2;
	char [] [char[]] workaround;
	
	result[section] = workaround;
	
	foreach (line;std.string.split(ini, "\n")) {
		//if ((std.string.strip(line).length > 0) && (std.string.strip(line)[0] != '#')) {
			r2 = re_search(`^[\s]*\[([^\]]+)\]$`, line);
			if (r2) {
				section = r2[1];
				result[section] = workaround;			// using result[section][$name] = $value directly throws ArrayBoundsError
			}
			
			r2 = re_search(`^([^\=]+)\=(.+)$`, line);
			if (r2) {
				result[section][r2[1]] = r2[2];
			}
		//}
	}
	
	return result;
}

int write_ini(char[] name, ini_obj ini) {
	_iobuf* inifile;
	char [] result;
	
	inifile = fopen(name.ptr,"w".ptr);
	
	if (inifile) {
		result = code_ini(ini);
		fwritef(inifile, result.ptr);
		
		fclose(inifile);
		return 1;
	}

	return 0;
}

char[] code_ini(ini_obj ini) {
	char [][]result;
	
	foreach (section; ini.keys) {
		if (section != "")
			result ~= std.string.format("[%s]", section);
		foreach(line; ini[section].keys) {
			result ~= std.string.format("%s=%s", line, ini[section][line]);
		}
	}
	return std.string.join(result,"\n");
}
