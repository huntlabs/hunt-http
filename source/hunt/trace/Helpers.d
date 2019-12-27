module hunt.trace.Helpers;

import core.stdc.time;
import std.datetime;
import std.bitmanip;
import std.digest;
import hunt.logging;

long hnsecs() @property {
    return Clock.currStdTime - unixTimeToStdTime(0);
}

long usecs() @property {
    return hnsecs / 10;
}

long msecs() @property {
    return hnsecs / 10000;
}

int secs() @property {
    return cast(int) time(null);
}

//16bytes
string ID() @property {
    ubyte[8] bs = nativeToBigEndian(hnsecs);
    return toHexString!(LetterCase.lower)(bs.dup);
}

string LID() @property {
    return ID ~ ID;
}
