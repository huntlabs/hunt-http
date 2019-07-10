module hunt.http.codec.http.model.HttpStatus;

import hunt.util.ObjectUtils;
import std.conv;
import std.format;

alias HttpStatusCode = HttpStatus.Code;

/**
 * <p>
 * Http Status Codes
 * </p>
 * 
 * @see <a href="http://www.iana.org/assignments/http-status-codes/">IANA HTTP
 *      Status Code Registry</a>
 */
class HttpStatus {
	enum CONTINUE_100 = 100;
	enum SWITCHING_PROTOCOLS_101 = 101;
	enum PROCESSING_102 = 102;

	enum OK_200 = 200;
	enum CREATED_201 = 201;
	enum ACCEPTED_202 = 202;
	enum NON_AUTHORITATIVE_INFORMATION_203 = 203;
	enum NO_CONTENT_204 = 204;
	enum RESET_CONTENT_205 = 205;
	enum PARTIAL_CONTENT_206 = 206;
	enum MULTI_STATUS_207 = 207;

	enum MULTIPLE_CHOICES_300 = 300;
	enum MOVED_PERMANENTLY_301 = 301;
	enum MOVED_TEMPORARILY_302 = 302;
	enum FOUND_302 = 302;
	enum SEE_OTHER_303 = 303;
	enum NOT_MODIFIED_304 = 304;
	enum USE_PROXY_305 = 305;
	enum TEMPORARY_REDIRECT_307 = 307;
	enum PERMANENT_REDIRECT_308 = 308;

	enum BAD_REQUEST_400 = 400;
	enum UNAUTHORIZED_401 = 401;
	enum PAYMENT_REQUIRED_402 = 402;
	enum FORBIDDEN_403 = 403;
	enum NOT_FOUND_404 = 404;
	enum METHOD_NOT_ALLOWED_405 = 405;
	enum NOT_ACCEPTABLE_406 = 406;
	enum PROXY_AUTHENTICATION_REQUIRED_407 = 407;
	enum REQUEST_TIMEOUT_408 = 408;
	enum CONFLICT_409 = 409;
	enum GONE_410 = 410;
	enum LENGTH_REQUIRED_411 = 411;
	enum PRECONDITION_FAILED_412 = 412;
	deprecated("")
	enum REQUEST_ENTITY_TOO_LARGE_413 = 413;
	enum PAYLOAD_TOO_LARGE_413 = 413;
	deprecated("")
	enum REQUEST_URI_TOO_LONG_414 = 414;
	enum URI_TOO_LONG_414 = 414;
	enum UNSUPPORTED_MEDIA_TYPE_415 = 415;
	deprecated("")
	enum REQUESTED_RANGE_NOT_SATISFIABLE_416 = 416;
	enum RANGE_NOT_SATISFIABLE_416 = 416;
	enum EXPECTATION_FAILED_417 = 417;
	enum IM_A_TEAPOT_418 = 418;
	enum ENHANCE_YOUR_CALM_420 = 420;
	enum MISDIRECTED_REQUEST_421 = 421;
	enum UNPROCESSABLE_ENTITY_422 = 422;
	enum LOCKED_423 = 423;
	enum FAILED_DEPENDENCY_424 = 424;
	enum UPGRADE_REQUIRED_426 = 426;
	enum PRECONDITION_REQUIRED_428 = 428;
	enum TOO_MANY_REQUESTS_429 = 429;
	enum REQUEST_HEADER_FIELDS_TOO_LARGE_431 = 431;
	enum UNAVAILABLE_FOR_LEGAL_REASONS_451 = 451;

	enum INTERNAL_SERVER_ERROR_500 = 500;
	enum NOT_IMPLEMENTED_501 = 501;
	enum BAD_GATEWAY_502 = 502;
	enum SERVICE_UNAVAILABLE_503 = 503;
	enum GATEWAY_TIMEOUT_504 = 504;
	enum HTTP_VERSION_NOT_SUPPORTED_505 = 505;
	enum INSUFFICIENT_STORAGE_507 = 507;
	enum LOOP_DETECTED_508 = 508;
	enum NOT_EXTENDED_510 = 510;
	enum NETWORK_AUTHENTICATION_REQUIRED_511 = 511;

	enum MAX_CODE = 511  + 1;

	private __gshared Code[] codeMap; // = new Code[MAX_CODE + 1];

	shared static this() {
		codeMap = new Code[MAX_CODE + 1];
		foreach (Code code ; Code.values()) {
			codeMap[code._code] = code;
		}
	}

	struct Code {
		enum Code Null = Code(MAX_CODE, "");
		enum Code CONTINUE = Code(CONTINUE_100, "Continue");
        enum Code SWITCHING_PROTOCOLS = Code(SWITCHING_PROTOCOLS_101, "Switching Protocols");
        enum Code PROCESSING = Code(PROCESSING_102, "Processing");


        enum Code OK = Code(OK_200, "OK");
        enum Code CREATED = Code(CREATED_201, "Created");
        enum Code ACCEPTED = Code(ACCEPTED_202, "Accepted");
        enum Code NON_AUTHORITATIVE_INFORMATION = Code(NON_AUTHORITATIVE_INFORMATION_203, "Non Authoritative Information");
        enum Code NO_CONTENT = Code(NO_CONTENT_204, "No Content");
        enum Code RESET_CONTENT = Code(RESET_CONTENT_205, "Reset Content");
        enum Code PARTIAL_CONTENT = Code(PARTIAL_CONTENT_206, "Partial Content");
        enum Code MULTI_STATUS = Code(MULTI_STATUS_207, "Multi-Status");

        enum Code MULTIPLE_CHOICES = Code(MULTIPLE_CHOICES_300, "Multiple Choices");
        enum Code MOVED_PERMANENTLY = Code(MOVED_PERMANENTLY_301, "Moved Permanently");
        enum Code MOVED_TEMPORARILY = Code(MOVED_TEMPORARILY_302, "Moved Temporarily");
        enum Code FOUND = Code(FOUND_302, "Found");
        enum Code SEE_OTHER = Code(SEE_OTHER_303, "See Other");
        enum Code NOT_MODIFIED = Code(NOT_MODIFIED_304, "Not Modified");
        enum Code USE_PROXY = Code(USE_PROXY_305, "Use Proxy");
        enum Code TEMPORARY_REDIRECT = Code(TEMPORARY_REDIRECT_307, "Temporary Redirect");
        enum Code PERMANET_REDIRECT = Code(PERMANENT_REDIRECT_308, "Permanent Redirect");

        enum Code BAD_REQUEST = Code(BAD_REQUEST_400, "Bad Request");
        enum Code UNAUTHORIZED = Code(UNAUTHORIZED_401, "Unauthorized");
        enum Code PAYMENT_REQUIRED = Code(PAYMENT_REQUIRED_402, "Payment Required");
        enum Code FORBIDDEN = Code(FORBIDDEN_403, "Forbidden");
        enum Code NOT_FOUND = Code(NOT_FOUND_404, "Not Found");
        enum Code METHOD_NOT_ALLOWED = Code(METHOD_NOT_ALLOWED_405, "Method Not Allowed");
        enum Code NOT_ACCEPTABLE = Code(NOT_ACCEPTABLE_406, "Not Acceptable");
        enum Code PROXY_AUTHENTICATION_REQUIRED = Code(PROXY_AUTHENTICATION_REQUIRED_407, "Proxy Authentication Required");
        enum Code REQUEST_TIMEOUT = Code(REQUEST_TIMEOUT_408, "Request Timeout");
        enum Code CONFLICT = Code(CONFLICT_409, "Conflict");
        enum Code GONE = Code(GONE_410, "Gone");
        enum Code LENGTH_REQUIRED = Code(LENGTH_REQUIRED_411, "Length Required");
        enum Code PRECONDITION_FAILED = Code(PRECONDITION_FAILED_412, "Precondition Failed");
        enum Code PAYLOAD_TOO_LARGE = Code(PAYLOAD_TOO_LARGE_413, "Payload Too Large");
        enum Code URI_TOO_LONG = Code(URI_TOO_LONG_414, "URI Too Long");
        enum Code UNSUPPORTED_MEDIA_TYPE = Code(UNSUPPORTED_MEDIA_TYPE_415, "Unsupported Media Type");
        enum Code RANGE_NOT_SATISFIABLE = Code(RANGE_NOT_SATISFIABLE_416, "Range Not Satisfiable");
        enum Code EXPECTATION_FAILED = Code(EXPECTATION_FAILED_417, "Expectation Failed");
        enum Code IM_A_TEAPOT = Code(IM_A_TEAPOT_418, "I'm a Teapot");
        enum Code ENHANCE_YOUR_CALM = Code(ENHANCE_YOUR_CALM_420, "Enhance your Calm");
        enum Code MISDIRECTED_REQUEST = Code(MISDIRECTED_REQUEST_421, "Misdirected Request");
        enum Code UNPROCESSABLE_ENTITY = Code(UNPROCESSABLE_ENTITY_422, "Unprocessable Entity");
        enum Code LOCKED = Code(LOCKED_423, "Locked");
        enum Code FAILED_DEPENDENCY = Code(FAILED_DEPENDENCY_424, "Failed Dependency");
        enum Code UPGRADE_REQUIRED = Code(UPGRADE_REQUIRED_426, "Upgrade Required");
        enum Code PRECONDITION_REQUIRED = Code(PRECONDITION_REQUIRED_428, "Precondition Required");
        enum Code TOO_MANY_REQUESTS = Code(TOO_MANY_REQUESTS_429, "Too Many Requests");
        enum Code REQUEST_HEADER_FIELDS_TOO_LARGE = Code(REQUEST_HEADER_FIELDS_TOO_LARGE_431, "Request Header Fields Too Large");
        enum Code UNAVAILABLE_FOR_LEGAL_REASONS = Code(UNAVAILABLE_FOR_LEGAL_REASONS_451, "Unavailable for Legal Reason");

        enum Code INTERNAL_SERVER_ERROR = Code(INTERNAL_SERVER_ERROR_500, "Server Error");
        enum Code NOT_IMPLEMENTED = Code(NOT_IMPLEMENTED_501, "Not Implemented");
        enum Code BAD_GATEWAY = Code(BAD_GATEWAY_502, "Bad Gateway");
        enum Code SERVICE_UNAVAILABLE = Code(SERVICE_UNAVAILABLE_503, "Service Unavailable");
        enum Code GATEWAY_TIMEOUT = Code(GATEWAY_TIMEOUT_504, "Gateway Timeout");
        enum Code HTTP_VERSION_NOT_SUPPORTED = Code(HTTP_VERSION_NOT_SUPPORTED_505, "HTTP Version Not Supported");
        enum Code INSUFFICIENT_STORAGE = Code(INSUFFICIENT_STORAGE_507, "Insufficient Storage");
        enum Code LOOP_DETECTED = Code(LOOP_DETECTED_508, "Loop Detected");
        enum Code NOT_EXTENDED = Code(NOT_EXTENDED_510, "Not Extended");
        enum Code NETWORK_AUTHENTICATION_REQUIRED = Code(NETWORK_AUTHENTICATION_REQUIRED_511, "Network Authentication Required");
        

		private int _code;
		private string _message;

		private this(int code, string message) {
			this._code = code;
			_message = message;
		}

		mixin GetConstantValues!(Code);

		int getCode() {
			return _code;
		}

		string getMessage() {
			return _message;
		}

		bool equals(int code) {
			return (this._code == code);
		}

		string toString() {
			return format("[%03d %s]", this._code, this._message);
		}

		/**
		 * Simple test against an code to determine if it falls into the
		 * <code>Informational</code> message category as defined in the
		 * <a href="http://tools.ietf.org/html/rfc1945">RFC 1945 - HTTP/1.0</a>,
		 * and <a href="http://tools.ietf.org/html/rfc7231">RFC 7231 -
		 * HTTP/1.1</a>.
		 *
		 * @return true if within range of codes that belongs to
		 *         <code>Informational</code> messages.
		 */
		bool isInformational() {
			return HttpStatus.isInformational(this._code);
		}

		/**
		 * Simple test against an code to determine if it falls into the
		 * <code>Success</code> message category as defined in the
		 * <a href="http://tools.ietf.org/html/rfc1945">RFC 1945 - HTTP/1.0</a>,
		 * and <a href="http://tools.ietf.org/html/rfc7231">RFC 7231 -
		 * HTTP/1.1</a>.
		 *
		 * @return true if within range of codes that belongs to
		 *         <code>Success</code> messages.
		 */
		bool isSuccess() {
			return HttpStatus.isSuccess(this._code);
		}

		/**
		 * Simple test against an code to determine if it falls into the
		 * <code>Redirection</code> message category as defined in the
		 * <a href="http://tools.ietf.org/html/rfc1945">RFC 1945 - HTTP/1.0</a>,
		 * and <a href="http://tools.ietf.org/html/rfc7231">RFC 7231 -
		 * HTTP/1.1</a>.
		 *
		 * @return true if within range of codes that belongs to
		 *         <code>Redirection</code> messages.
		 */
		bool isRedirection() {
			return HttpStatus.isRedirection(this._code);
		}

		/**
		 * Simple test against an code to determine if it falls into the
		 * <code>Client Error</code> message category as defined in the
		 * <a href="http://tools.ietf.org/html/rfc1945">RFC 1945 - HTTP/1.0</a>,
		 * and <a href="http://tools.ietf.org/html/rfc7231">RFC 7231 -
		 * HTTP/1.1</a>.
		 *
		 * @return true if within range of codes that belongs to
		 *         <code>Client Error</code> messages.
		 */
		bool isClientError() {
			return HttpStatus.isClientError(this._code);
		}

		/**
		 * Simple test against an code to determine if it falls into the
		 * <code>Server Error</code> message category as defined in the
		 * <a href="http://tools.ietf.org/html/rfc1945">RFC 1945 - HTTP/1.0</a>,
		 * and <a href="http://tools.ietf.org/html/rfc7231">RFC 7231 -
		 * HTTP/1.1</a>.
		 *
		 * @return true if within range of codes that belongs to
		 *         <code>Server Error</code> messages.
		 */
		bool isServerError() {
			return HttpStatus.isServerError(this._code);
		}
	}

	/**
	 * Get the HttpStatusCode for a specific code
	 *
	 * @param code
	 *            the code to lookup.
	 * @return the {@link HttpStatus} if found, or null if not found.
	 */
	static Code getCode(int code) {
		if (code <= MAX_CODE) {
			return codeMap[code];
		}
		return Code.Null;
	}

	/**
	 * Get the status message for a specific code.
	 *
	 * @param code
	 *            the code to look up
	 * @return the specific message, or the code number itself if code does not
	 *         match known list.
	 */
	static string getMessage(int code) {
		Code codeEnum = getCode(code);
		if (codeEnum != Code.Null) {
			return codeEnum.getMessage();
		} else {
			return std.conv.to!(string)(code);
		}
	}

	/**
	 * Simple test against an code to determine if it falls into the
	 * <code>Informational</code> message category as defined in the
	 * <a href="http://tools.ietf.org/html/rfc1945">RFC 1945 - HTTP/1.0</a>, and
	 * <a href="http://tools.ietf.org/html/rfc7231">RFC 7231 - HTTP/1.1</a>.
	 *
	 * @param code
	 *            the code to test.
	 * @return true if within range of codes that belongs to
	 *         <code>Informational</code> messages.
	 */
	static bool isInformational(int code) {
		return ((100 <= code) && (code <= 199));
	}

	/**
	 * Simple test against an code to determine if it falls into the
	 * <code>Success</code> message category as defined in the
	 * <a href="http://tools.ietf.org/html/rfc1945">RFC 1945 - HTTP/1.0</a>, and
	 * <a href="http://tools.ietf.org/html/rfc7231">RFC 7231 - HTTP/1.1</a>.
	 *
	 * @param code
	 *            the code to test.
	 * @return true if within range of codes that belongs to
	 *         <code>Success</code> messages.
	 */
	static bool isSuccess(int code) {
		return ((200 <= code) && (code <= 299));
	}

	/**
	 * Simple test against an code to determine if it falls into the
	 * <code>Redirection</code> message category as defined in the
	 * <a href="http://tools.ietf.org/html/rfc1945">RFC 1945 - HTTP/1.0</a>, and
	 * <a href="http://tools.ietf.org/html/rfc7231">RFC 7231 - HTTP/1.1</a>.
	 *
	 * @param code
	 *            the code to test.
	 * @return true if within range of codes that belongs to
	 *         <code>Redirection</code> messages.
	 */
	static bool isRedirection(int code) {
		return ((300 <= code) && (code <= 399));
	}

	/**
	 * Simple test against an code to determine if it falls into the
	 * <code>Client Error</code> message category as defined in the
	 * <a href="http://tools.ietf.org/html/rfc1945">RFC 1945 - HTTP/1.0</a>, and
	 * <a href="http://tools.ietf.org/html/rfc7231">RFC 7231 - HTTP/1.1</a>.
	 *
	 * @param code
	 *            the code to test.
	 * @return true if within range of codes that belongs to
	 *         <code>Client Error</code> messages.
	 */
	static bool isClientError(int code) {
		return ((400 <= code) && (code <= 499));
	}

	/**
	 * Simple test against an code to determine if it falls into the
	 * <code>Server Error</code> message category as defined in the
	 * <a href="http://tools.ietf.org/html/rfc1945">RFC 1945 - HTTP/1.0</a>, and
	 * <a href="http://tools.ietf.org/html/rfc7231">RFC 7231 - HTTP/1.1</a>.
	 *
	 * @param code
	 *            the code to test.
	 * @return true if within range of codes that belongs to
	 *         <code>Server Error</code> messages.
	 */
	static bool isServerError(int code) {
		return ((500 <= code) && (code <= 599));
	}
}
