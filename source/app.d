import std.stdio;

// config/command line variables
string input;

int main(string[] args)
{

	auto buffer = readFile("bin/37");
	interpret(buffer);

	Instr instr;

	instr.write(Op.MOV);

	disassemble(instr, stdout);

	return 0;
}

enum Op : ubyte
{
	MOV,
}

struct Instr
{
	ubyte[] code;

	void write(Op op)
	{
		code ~= op;
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

void interpret(ref ubyte[] stream)
{
	Scanner scanner = Scanner(stream, stream.ptr);

	foreach (ubyte b1; scanner)
	{
		ubyte op = b1 >> 2;

		switch (op)
		{
		case 0b100010:
			ubyte d = (b1 & MOV_D_MASK) >> 1;
			ubyte w = (b1 & MOV_W_MASK);

			scanner.popFront();
			ubyte b2 = scanner.front();

			ubyte mod = (b2 & MOV_MOD_MASK) >> 6;
			ubyte reg = (b2 & MOV_REG_MASK) >> 3;
			ubyte rm = (b2 & MOV_RM_MASK);

			assert(mod & 0b11, "Mod is not register-register");
			break;
		default:
			writefln!"unhandled: %b"(op);
			break;
		}
	}
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
		writefln!"mov %s,%s"("ax", "bx");
		return offset + 1;
	}
}
