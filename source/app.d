import std.stdio;
import std.file;
import std.conv : octal, to, parse;

import diss;
import instr;
import scan;

int main(string[] args)
{
	auto file = args[1];
	assert(file.exists, "File: " ~ file ~ " doesn't exist");

	auto buffer = readBytes(file);

	Decode decoder;
	decoder
		.decode(buffer)
		.disassemble(stdout);

	return 0;
}

struct Reg
{
	ubyte addr;
	bool wide;
}

struct Stream
{
	Instr[] instructions;
}

ubyte[] readBytes(string path)
{
	File file = File(path, "r");
	scope (exit)
		file.close();

	return file.rawRead(new ubyte[file.size()]);
}

enum MOV_MASK = 0x88; // 10001000
enum MOV_D_MASK = 0x2; // 00000010
enum MOV_W_MASK = 0x1; // 00000001
enum MOV_MOD_MASK = 0xC0; // 11000000
enum MOV_REG_MASK = 0x38; // 00111000
enum MOV_RM_MASK = 0x07; // 00000111

struct Decode
{
	Scanner scanner;
	Stream program;

	Stream decode(ubyte[] stream)
	{
		scanner = Scanner(stream, stream.ptr);

		bool errored;
		while (!errored && !scanner.empty)
		{
			ubyte b1 = scanner.pop();

			switch (b1)
			{
			case (octal!270): .. case (octal!277):
				immToReg(b1);
				break;

			case (octal!210): .. case (octal!213):
				// case (octal!214):
				// case (octal!216):
				mov(b1);
				break;

			default:
				writefln!"unhandled: %o"(b1);
				errored = true;
				break;
			}
		}

		return program;
	}

	void mov(ubyte mov)
	{
		// mov dest, src

		bool regIsDest;
		bool wideReg;
		bool wideDisp;
		bool hasDisp;

		ubyte xrm = scanner.pop();

		ubyte x = (octal!700 & xrm) >> 6;
		ubyte r = (octal!70 & xrm) >> 3;
		ubyte m = (octal!7 & xrm);

		final switch (mov)
		{
		case (octal!210): // mov Eb, Rb
			break;
		case (octal!211): // mov Ew, Rw
			wideReg = true;
			break;
		case (octal!212): // mov Rb, Eb
			regIsDest = true;
			break;
		case (octal!213): // mov Rw, Ew
			wideReg = true;
			regIsDest = true;
			break;
			// case (octal!214): // mov Ew, SR
			// case (octal!216): // mov SR, Ew
			// 	break;
		}

		final switch (x)
		{
		case octal!0:
			break;
		case octal!1:
			hasDisp = true;
			break;
		case octal!2:
			hasDisp = true;
			wideDisp = true;
			break;
		case octal!3:
			break;
		}

		if (x == octal!3)
		{
			program.instructions ~= new Mov(mov, r, m);
		}
		else
		{
			short disp = hasDisp ? (wideDisp ? scanner.popWord() : scanner.pop()) : 0;

			program.instructions ~= regIsDest ?
				new MovSrcAdd(mov, r, m, disp) : new MovDestAdd(mov, r, m, disp);
		}
	}

	void immToReg(ubyte mov)
	{
		// 27r Dw	mov Rw, Dw
		ubyte r = (octal!7 & mov);
		ushort word = scanner.popWord();

		program.instructions ~= new MovImm(mov, r, word);
	}
}
