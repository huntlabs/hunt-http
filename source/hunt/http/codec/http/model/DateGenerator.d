module hunt.http.codec.http.model.DateGenerator;

import hunt.Exceptions;
import hunt.text.Common;
import hunt.util.StringBuilder;

import std.datetime;
import std.format;
import std.array;

/**
 * ThreadLocal Date formatters for HTTP style dates.
 */
class DateGenerator {
	// private static TimeZone __GMT = TimeZone.getTimeZone("GMT");

	// shared static this() {
	// 	__GMT.setID("GMT");
	// }

	__gshared string[] DAYS = [ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" ];
	__gshared string[] MONTHS = [ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

	private static DateGenerator __dateGenerator;
	static this()
	{
		__dateGenerator = new DateGenerator();
	}


	// static string __01Jan1970 = DateGenerator.formatDate(0);

	/**
	 * Format HTTP date "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
	 * 
	 * @param date
	 *            the date
	 * @return the formatted date
	 */
	static string formatDate(SysTime date) {
		return __dateGenerator.doFormatDate(date);
	}


	// static string formatDate(long date) {
	// 	return __dateGenerator.doFormatDate(date);
	// }

	/**
	 * Format "EEE, dd-MMM-yyyy HH:mm:ss 'GMT'" for cookies
	 * 
	 * @param buf
	 *            the buffer to put the formatted date into
	 * @param date
	 *            the date in milliseconds
	 */
	static void formatCookieDate(StringBuilder buf, long date) {
		__dateGenerator.doFormatCookieDate(buf, date);
	}

	/**
	 * Format "EEE, dd-MMM-yyyy HH:mm:ss 'GMT'" for cookies
	 * 
	 * @param date
	 *            the date in milliseconds
	 * @return the formatted date
	 */
	static string formatCookieDate(long date) {
		StringBuilder buf = new StringBuilder(28);
		formatCookieDate(buf, date);
		return buf.toString();
	}
	

	string doFormatDate(SysTime date)
	{
		Appender!string buf;

		DateTime dt = cast(DateTime)date;

		DayOfWeek day_of_week = dt.dayOfWeek;
		int day_of_month = dt.day;
		Month month = dt.month;
		int year = dt.year;
		int century = year / 100;
		year = year % 100;

		int hours = dt.hour;
		int minutes = dt.minute;
		int seconds = dt.second;

		buf.put(DAYS[day_of_week]);
		buf.put(',');
		buf.put(' ');
		buf.put(format("%02d", day_of_month));

		buf.put(' ');
		buf.put(MONTHS[month - Month.jan]);
		buf.put(' ');
		buf.put(format("%02d", century));
		buf.put(format("%02d", year));

		buf.put(' ');
		buf.put(format("%02d", hours));
		buf.put(':');
		buf.put(format("%02d", minutes));
		buf.put(':');
		buf.put(format("%02d", seconds));
		buf.put(" GMT");
		return buf.data;
	}

	// private StringBuilder buf = new StringBuilder(32);
	// private GregorianCalendar gc = new GregorianCalendar(__GMT);

	/**
	 * Format HTTP date "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
	 * 
	 * @param date
	 *            the date in milliseconds
	 * @return the formatted date
	 */
	string doFormatDate(long date) {
		implementationMissing();
		return "";
	}

	/**
	 * Format "EEE, dd-MMM-yy HH:mm:ss 'GMT'" for cookies
	 * 
	 * @param buf
	 *            the buffer to format the date into
	 * @param date
	 *            the date in milliseconds
	 */
	void doFormatCookieDate(StringBuilder buf, long date) {
		implementationMissing();
		// gc.setTimeInMillis(date);

		// int day_of_week = gc.get(Calendar.DAY_OF_WEEK);
		// int day_of_month = gc.get(Calendar.DAY_OF_MONTH);
		// int month = gc.get(Calendar.MONTH);
		// int year = gc.get(Calendar.YEAR);
		// year = year % 10000;

		// int epoch = cast(int) ((date / 1000) % (60 * 60 * 24));
		// int seconds = epoch % 60;
		// epoch = epoch / 60;
		// int minutes = epoch % 60;
		// int hours = epoch / 60;

		// buf.append(DAYS[day_of_week]);
		// buf.append(',');
		// buf.append(' ');
		// StringUtils.append2digits(buf, day_of_month);

		// buf.append('-');
		// buf.append(MONTHS[month]);
		// buf.append('-');
		// StringUtils.append2digits(buf, year / 100);
		// StringUtils.append2digits(buf, year % 100);

		// buf.append(' ');
		// StringUtils.append2digits(buf, hours);
		// buf.append(':');
		// StringUtils.append2digits(buf, minutes);
		// buf.append(':');
		// StringUtils.append2digits(buf, seconds);
		// buf.append(" GMT");
	}
}
