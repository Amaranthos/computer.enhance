module diss;

import std.stdio : File, writeln, writefln;
import std.format;

import app : Reg, Stream;
import instr;
import ops;
import reg;

bool outputOctal = false;

void disassemble(Stream stream, ref File file)
{
	file.writeln("bits 16");
	foreach (Instr instr; stream.instructions)
	{
		writefln!"%s%s"(outputOctal ? format!"(%o) "(instr.op) : "", instr);
	}
}
