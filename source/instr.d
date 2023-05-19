module instr;

import std.conv : octal;
import std.format;

import reg;

abstract class Instr
{
	ubyte op;

	ubyte isWide();
}

class Mov : Instr
{
	ubyte src;
	ubyte dest;

	this(ubyte op, ubyte src, ubyte dest)
	{
		this.op = op;
		this.src = src;
		this.dest = dest;
	}

	override ubyte isWide() const
	{
		return (octal!7 & op) % 2;
	}

	override string toString() const
	{
		return format!"mov %s, %s"(regNames[dest][isWide], regNames[src][isWide]);
	}
}

class MovImm : Instr
{
	ubyte dest;
	ushort val;

	this(ubyte op, ubyte dest, ushort val)
	{
		this.op = op;
		this.dest = dest;
		this.val = val;
	}

	override ubyte isWide() const
	{
		// 26r Db	mov Rb, Db
		// 27r Dw	mov Rw, Dw
		return cast(ubyte)(((octal!70 & op) >> 3) - 6);
	}

	override string toString() const
	{
		return format!"mov %s, %s"(regNames[dest][isWide], val);
	}
}

class MovSrcAdd : Instr
{
	ubyte src;
	ubyte dest;
	ushort disp;

	this(ubyte op, ubyte dest, ubyte src, ushort disp = 0)
	{
		this.op = op;
		this.src = src;
		this.dest = dest;
		this.disp = disp;
	}

	override ubyte isWide() const
	{
		return (octal!7 & op) % 2;
	}

	override string toString() const
	{
		return format!"mov %s, [%s%s]"(regNames[dest][isWide], addressing[src], dispToString(disp));
	}
}

class MovDestAdd : Instr
{
	ubyte src;
	ubyte dest;
	ushort disp;

	this(ubyte op, ubyte src, ubyte dest, ushort disp = 0)
	{
		this.op = op;
		this.src = src;
		this.dest = dest;
		this.disp = disp;
	}

	override ubyte isWide() const
	{
		return (octal!7 & op) % 2;
	}

	override string toString() const
	{
		return format!"mov [%s%s], %s"(addressing[dest], dispToString(disp), regNames[src][isWide]);
	}
}

string dispToString(ushort disp)
{
	return disp ? disp.format!" + %s" : "";
}
