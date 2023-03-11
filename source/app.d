import std.stdio;
import std.file;
import std.container;

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
	MOV_RR,
	MOV_RM,
	MOV_MR,
	MOV_IR,
}

static string[2][ubyte] regNames;
static string[ubyte] addrCalcs;

shared static this()
{
	regNames = [
		0b000: ["al", "ax"],
		0b001: ["cl", "cx"],
		0b010: ["dl", "dx"],
		0b011: ["bl", "bx"],
		0b100: ["ah", "sp"],
		0b101: ["ch", "bp"],
		0b110: ["dh", "si"],
		0b111: ["bh", "di"],
	];

	addrCalcs = [
		0b000: "bx + si",
		0b001: "bx + di",
		0b010: "bp + si",
		0b011: "bp + di",
		0b100: "si",
		0b101: "di",
		0b110: "bp",
		0b111: "bx",
	];
}

struct Reg
{
	ubyte addr;
	bool wide;
}

struct Mem
{
	ubyte addr;
	ushort offset;
}

struct Constant
{
	ubyte addr;
	ushort val;
}

struct Instr
{
	ubyte[] code;
	DList!Reg registers;
	DList!Mem memory;
	DList!ushort constants;

	void write(Op op)
	{
		code ~= op;
	}

	void writeReg(Reg register)
	{
		registers ~= register;
	}

	void writeMem(Mem mem)
	{
		memory ~= mem;
	}

	void writeConstant(ushort val)
	{
		constants ~= val;
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

		switch (b1)
		{
		case 0b10001000: .. case 0b10001011: // NOTE: Register to register
			ubyte d = (b1 & MOV_D_MASK) >> 1;
			ubyte w = (b1 & MOV_W_MASK);

			ubyte b2 = scanner.pop();

			ubyte mod = (b2 & MOV_MOD_MASK) >> 6;
			ubyte reg = (b2 & MOV_REG_MASK) >> 3;
			ubyte rm = (b2 & MOV_RM_MASK);

			final switch (mod)
			{
			case 0b00:
				ubyte src, dest;

				instructions.write(d ? Op.MOV_RM : Op.MOV_MR);
				instructions.writeReg(Reg(reg, !!w));
				instructions.writeMem(Mem(rm, 0));
				break;

			case 0b01:
				ubyte b3 = scanner.pop();

				instructions.write(d ? Op.MOV_RM : Op.MOV_MR);
				instructions.writeReg(Reg(reg, !!w));
				instructions.writeMem(Mem(rm, b3));
				break;

			case 0b10:
				ubyte b3 = scanner.pop();
				ubyte b4 = scanner.pop();

				instructions.write(d ? Op.MOV_RM : Op.MOV_MR);
				instructions.writeReg(Reg(reg, !!w));
				instructions.writeMem(Mem(rm, b4 << 8 | b3));
				break;

			case 0b11:
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

				instructions.write(Op.MOV_RR);
				instructions.writeReg(Reg(dest, !!w));
				instructions.writeReg(Reg(src, !!w));
				break;
			}
			break;

		case 0b10110000: .. case 0b10111111:
			ubyte w = b1 & 0b00001000;
			ubyte reg = b1 & 0b00000111;

			ubyte b2 = scanner.pop();
			ubyte b3 = w ? scanner.pop() : 0;

			instructions.write(Op.MOV_IR);
			instructions.writeReg(Reg(reg, !!w));
			instructions.writeConstant(b3 << 8 | b2);

			break;

		case 0b11000110: .. case 0b11000111:
			ubyte w = (b1 & MOV_W_MASK);
			ubyte b2 = scanner.pop();
			ubyte mod = (b2 & MOV_MOD_MASK) >> 6;

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

	Op op = cast(Op) instr.code[offset];
	final switch (op) with (Op)
	{
	case MOV_RR:
		assert(!instr.registers.empty);
		Reg dest = instr.registers.popQ();
		Reg src = instr.registers.popQ();

		writefln!"mov %s, %s"(regNames[dest.addr][dest.wide], regNames[src.addr][src.wide]);
		return offset + 1;

	case MOV_MR:
		assert(!instr.registers.empty());
		assert(!instr.memory.empty());

		Mem dest = instr.memory.popQ();
		Reg src = instr.registers.popQ();

		writefln!"mov [%s + %s], %s"(addrCalcs[dest.addr], dest.offset, regNames[src.addr][src.wide]);
		return offset + 1;

	case MOV_RM:
		assert(!instr.registers.empty());
		assert(!instr.memory.empty());

		Reg dest = instr.registers.popQ();
		Mem src = instr.memory.popQ();

		writefln!"mov %s, [%s + %s]"(regNames[dest.addr][dest.wide], addrCalcs[src.addr], src
				.offset);
		return offset + 1;

	case MOV_IR:
		assert(!instr.registers.empty());

		Reg dest = instr.registers.popQ();
		short val = cast(short) instr.constants.popQ();

		writefln!"mov %s, %s"(regNames[dest.addr][dest.wide], val);
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

auto popQ(T)(scope ref DList!T a)
{
	auto f = a.front;
	a.removeFront();
	return f;
}
