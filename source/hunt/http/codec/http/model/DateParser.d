module hunt.http.codec.http.model.DateParser;

// import java.text.SimpleDateFormat;
// import java.util.Date;
// import java.util.Locale;
// import java.util.TimeZone;

/**
 * ThreadLocal data parsers for HTTP style dates
 *
 */
class DateParser {
	// private static TimeZone __GMT = TimeZone.getTimeZone("GMT");

	// static this() {
	// 	__GMT.setID("GMT");
	// }

	__gshared string[] __dateReceiveFmt = [ "EEE, dd MMM yyyy HH:mm:ss zzz", "EEE, dd-MMM-yy HH:mm:ss",
			"EEE MMM dd HH:mm:ss yyyy",

			"EEE, dd MMM yyyy HH:mm:ss", "EEE dd MMM yyyy HH:mm:ss zzz", "EEE dd MMM yyyy HH:mm:ss",
			"EEE MMM dd yyyy HH:mm:ss zzz", "EEE MMM dd yyyy HH:mm:ss", "EEE MMM-dd-yyyy HH:mm:ss zzz",
			"EEE MMM-dd-yyyy HH:mm:ss", "dd MMM yyyy HH:mm:ss zzz", "dd MMM yyyy HH:mm:ss", "dd-MMM-yy HH:mm:ss zzz",
			"dd-MMM-yy HH:mm:ss", "MMM dd HH:mm:ss yyyy zzz", "MMM dd HH:mm:ss yyyy", "EEE MMM dd HH:mm:ss yyyy zzz",
			"EEE, MMM dd HH:mm:ss yyyy zzz", "EEE, MMM dd HH:mm:ss yyyy", "EEE, dd-MMM-yy HH:mm:ss zzz",
			"EEE dd-MMM-yy HH:mm:ss zzz", "EEE dd-MMM-yy HH:mm:ss" ];

	// static long parseDate(string date) {
	// 	return __dateParser.parse(date);
	// }

	// private static DateParser __dateParser = new DateParser();

	// SimpleDateFormat[] _dateReceive = new SimpleDateFormat[__dateReceiveFmt.length];

	// private long parse(string dateVal) {
	// 	for (int i = 0; i < _dateReceive.length; i++) {
	// 		if (_dateReceive[i] == null) {
	// 			_dateReceive[i] = new SimpleDateFormat(__dateReceiveFmt[i], Locale.US);
	// 			_dateReceive[i].setTimeZone(__GMT);
	// 		}

	// 		try {
	// 			Date date = cast(Date) _dateReceive[i].parseObject(dateVal);
	// 			return date.getTime();
	// 		} catch (java.lang.Exception e) {
	// 			// log.ignore(e);
	// 		}
	// 	}

	// 	if (dateVal.endsWith(" GMT")) {
	// 		string val = dateVal.substring(0, dateVal.length() - 4);

	// 		foreach (SimpleDateFormat element ; _dateReceive) {
	// 			try {
	// 				Date date = cast(Date) element.parseObject(val);
	// 				return date.getTime();
	// 			} catch (java.lang.Exception e) {
	// 				// log.ignore(e);
	// 			}
	// 		}
	// 	}
	// 	return -1;
	// }
}
