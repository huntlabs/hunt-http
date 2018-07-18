module hunt.http.codec.http.frame.FrameType;

import std.traits;

enum FrameType {
	DATA=0,
    HEADERS=1,
    PRIORITY=2,
    RST_STREAM=3,
    SETTINGS=4,
    PUSH_PROMISE=5,
    PING=6,
    GO_AWAY=7,
    WINDOW_UPDATE=8,
    CONTINUATION=9,
    // Synthetic frames only needed by the implementation.
    PREFACE=10,
    DISCONNECT=11
}

enum FrameTypeSize = EnumMembers!(FrameType).length;