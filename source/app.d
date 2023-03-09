import std.stdio;
import std.file;

int main(string[] args)
{
	auto file = args[1];
	assert(file.exists, "File: " ~ file ~ " doesn't exist");

	auto buffer = readFile(file);
	Instr instr = interpret(buffer);
	disassemble(instr, stdout);

	return 0;
}

enum Op : ubyte
{
	MOV,
}

static string[2][ubyte] registers;

shared static this()
{
	registers = [
		0b000: ["al", "ax"],
		0b001: ["cl", "cx"],
		0b010: ["dl", "dx"],
		0b011: ["bl", "bx"],
		0b100: ["ah", "sp"],
		0b101: ["ch", "bp"],
		0b110: ["dh", "si"],
		0b111: ["bh", "di"],
	];
}

struct Reg
{
	ubyte addr;
	bool wide;
}

struct Instr
{
	ubyte[] code;
	Reg[] registers;

	void write(Op op)
	{
		code ~= op;
	}

	void writeReg(Reg register)
	{
		registers ~= register;
	}
}

ubyte[] readFile(string path)
{
	File file = File(path, "r");
	scope (exit)
		file.close();

	return file.rawRead(new ubyte[file.size()]);
}

struct Scanner
{
	ubyte[] buffer;
	ubyte* current;

	bool empty()
	{
		return current >= buffer.ptr + buffer.length;
	}

	void popFront()
	{
		++current;
	}

	ubyte front()
	{
		return *current;
	}
}

enum MOV_MASK = 0x88; // 10001000
enum MOV_D_MASK = 0x2; // 00000010
enum MOV_W_MASK = 0x1; // 00000001
enum MOV_MOD_MASK = 0xC0; // 11000000
enum MOV_REG_MASK = 0x38; // 00111000
enum MOV_RM_MASK = 0x07; // 00000111

Instr interpret(ref ubyte[] stream)
{
	Scanner scanner = Scanner(stream, stream.ptr);
	Instr instructions;

	while (!scanner.empty)
	{
		ubyte b1 = scanner.pop();
		switch (b1 >> 2)
		{
		case 0b100010:
			ubyte d = (b1 & MOV_D_MASK) >> 1;
			ubyte w = (b1 & MOV_W_MASK);

			ubyte b2 = scanner.pop();

			ubyte mod = (b2 & MOV_MOD_MASK) >> 6;
			assert(mod & 0b11, "Mod is not register-register");

			ubyte reg = (b2 & MOV_REG_MASK) >> 3;
			ubyte rm = (b2 & MOV_RM_MASK);

			ubyte src, dest;
			if (d)
			{
				dest = reg;
				src = rm;
			}
			else
			{
				dest = rm;
				src = reg;
			}

			instructions.write(Op.MOV);
			instructions.writeReg(Reg(dest, !!w));
			instructions.writeReg(Reg(src, !!w));
			break;

		default:
			writefln!"unhandled: %b"(b1);
			break;
		}
	}

	return instructions;
}

void disassemble(Instr instr, ref File file)
{
	file.writeln("bits 16");
	for (uint offset = 0; offset < instr.code.length;)
	{
		offset = disassemble(instr, offset);
	}
}

uint disassemble(Instr instr, uint offset)
{
	ubyte op = instr.code[offset];
	final switch (op) with (Op)
	{
	case MOV:
		assert(instr.registers.length >= 2);
		Reg dest = instr.registers[offset * 2];
		Reg src = instr.registers[offset * 2 + 1];

		writefln!"mov %s, %s"(registers[dest.addr][dest.wide], registers[src.addr][src.wide]);
		return offset + 1;
	}
}

import std.range : front, popFront, isInputRange;

auto pop(T)(scope ref T a) if (isInputRange!T)
{
	auto f = a.front;
	a.popFront();
	return f;
}
