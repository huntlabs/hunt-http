module hunt.http.codec.websocket.model.handler;

import hunt.http.codec.websocket.frame.Frame;
import hunt.util.functional;

alias OutgoingFramesHandler = void delegate(Frame frame, Callback callback);