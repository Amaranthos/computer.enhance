module reg;

import std.conv : octal;

string[2][ubyte] regNames; // NOTE: [idx][byte, word]
string[ubyte] addressing;

static this()
{
	regNames = [
		0b000: ["al", "ax"], // 0
		0b001: ["cl", "cx"], // 1
		0b010: ["dl", "dx"], // 2
		0b011: ["bl", "bx"], // 3
		0b100: ["ah", "sp"], // 4
		0b101: ["ch", "bp"], // 5
		0b110: ["dh", "si"], // 6
		0b111: ["bh", "di"], // 7
	];

	addressing = [
		octal!"0": "bx + si",
		octal!"1": "bx + di",
		octal!"2": "bp + si",
		octal!"3": "bp + di",
		octal!"4": "si",
		octal!"5": "di",
		octal!"6": "bp",
		octal!"7": "bx",
	];
}
