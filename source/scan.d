module scan;

import std.range : front, popFront, isInputRange;

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

	ubyte pop()
	{
		auto f = front;
		popFront();
		return f;
	}

	ushort popWord()
	{
		ushort res = *(cast(ushort*) current[0 .. 1]);
		current += 2;
		return res;
	}
}

auto pop(T)(scope ref T a) if (isInputRange!T)
{
	auto f = a.front;
	a.popFront();
	return f;
}
