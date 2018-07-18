module hunt.http.codec.http.frame.ErrorCode;

enum ErrorCode {
	NO_ERROR=0,
    PROTOCOL_ERROR=1,
    INTERNAL_ERROR=2,
    FLOW_CONTROL_ERROR=3,
    SETTINGS_TIMEOUT_ERROR=4,
    STREAM_CLOSED_ERROR=5,
    FRAME_SIZE_ERROR=6,
    REFUSED_STREAM_ERROR=7,
    CANCEL_STREAM_ERROR=8,
    COMPRESSION_ERROR=9,
    HTTP_CONNECT_ERROR=10,
    ENHANCE_YOUR_CALM_ERROR=11,
    INADEQUATE_SECURITY_ERROR=12,
    HTTP_1_1_REQUIRED_ERROR=13
}

bool isValidErrorCode(int code)
{
    return code>= cast(int)ErrorCode.NO_ERROR && code<= cast(int)ErrorCode.HTTP_1_1_REQUIRED_ERROR;
}