module hunt.http.codec.http.model.QuotedQualityCSV;

// import java.util.ArrayList;
// import java.util.Iterator;
import hunt.collection.List;
// import java.util.function.Function;


/**
 * : a quoted comma separated list of quality values in accordance with
 * RFC7230 and RFC7231. Values are returned sorted in quality order, with OWS
 * and the quality parameters removed.
 *
 * @see "https://tools.ietf.org/html/rfc7230#section-3.2.6"
 * @see "https://tools.ietf.org/html/rfc7230#section-7"
 * @see "https://tools.ietf.org/html/rfc7231#section-5.3.1"
 */
// class QuotedQualityCSV :QuotedCSV : Iterable<string> {
//     private static Double ZERO = 0.0;
//     private static Double ONE = 1.0;

//     /**
//      * Function to apply a most specific MIME encoding secondary ordering
//      */
//     static Function<string, Integer> MOST_SPECIFIC = s -> {
//         string[] elements = s.split("/");
//         return 1000000 * elements.length + 1000 * elements[0].length() + elements[elements.length - 1].length();
//     };

//     private List<Double> _quality = new ArrayList<>();
//     private bool _sorted = false;
//     private Function<string, Integer> _secondaryOrdering;


//     /**
//      * Sorts values with equal quality according to the length of the value string.
//      */
//     this() {
//         this((s) -> 0);
//     }

//     /**
//      * Sorts values with equal quality according to given order.
//      *
//      * @param preferredOrder Array indicating the preferred order of known values
//      */
//     this(string[] preferredOrder) {
//         this((s) -> {
//             for (int i = 0; i < preferredOrder.length; ++i)
//                 if (preferredOrder[i].equals(s))
//                     return preferredOrder.length - i;

//             if ("*".equals(s))
//                 return preferredOrder.length;

//             return MIN_VALUE;
//         });
//     }

//     /**
//      * Orders values with equal quality with the given function.
//      *
//      * @param secondaryOrdering Function to apply an ordering other than specified by quality
//      */
//     this(Function<string, Integer> secondaryOrdering) {
//         this._secondaryOrdering = secondaryOrdering;
//     }

//     override
//     protected void parsedValue(StringBuffer buffer) {
//         super.parsedValue(buffer);
//         _quality.add(ONE);
//     }

//     override
//     protected void parsedParam(StringBuffer buffer, int valueLength, int paramName, int paramValue) {
//         if (paramName < 0) {
//             if (buffer.charAt(buffer.length() - 1) == ';') {
//                 buffer.setLength(buffer.length() - 1);
//             }
//         } else if (paramValue >= 0 &&
//                 buffer.charAt(paramName) == 'q' && paramValue > paramName &&
//                 buffer.length() >= paramName && buffer.charAt(paramName + 1) == '=') {
//             Double q;
//             try {
//                 q = (_keepQuotes && buffer.charAt(paramValue) == '"')
//                         ? new Double(buffer.substring(paramValue + 1, buffer.length() - 1))
//                         : new Double(buffer.substring(paramValue));
//             } catch (Exception e) {
//                 q = ZERO;
//             }
//             buffer.setLength(std.algorithm.max(0, paramName - 1));

//             if (!ONE.equals(q)) {
//                 _quality.set(_quality.size() - 1, q);
//             }
//         }
//     }

//     List<string> getValues() {
//         if (!_sorted) {
//             sort();
//         }
//         return _values;
//     }

//     override
//     Iterator<string> iterator() {
//         if (!_sorted) {
//             sort();
//         }
//         return _values.iterator();
//     }

//     protected void sort() {
//         _sorted = true;

//         Double last = ZERO;
//         int lastSecondaryOrder = Integer.MIN_VALUE;

//         for (int i = _values.size(); i-- > 0; ) {
//             string v = _values.get(i);
//             Double q = _quality.get(i);

//             int compare = last.compareTo(q);
//             if (compare > 0 || (compare == 0 && _secondaryOrdering.apply(v) < lastSecondaryOrder)) {
//                 _values.set(i, _values.get(i + 1));
//                 _values.set(i + 1, v);
//                 _quality.set(i, _quality.get(i + 1));
//                 _quality.set(i + 1, q);
//                 last = ZERO;
//                 lastSecondaryOrder = 0;
//                 i = _values.size();
//                 continue;
//             }

//             last = q;
//             lastSecondaryOrder = _secondaryOrdering.apply(v);
//         }

//         int last_element = _quality.size();
//         while (last_element > 0 && _quality.get(--last_element).equals(ZERO)) {
//             _quality.remove(last_element);
//             _values.remove(last_element);
//         }
//     }
// }
