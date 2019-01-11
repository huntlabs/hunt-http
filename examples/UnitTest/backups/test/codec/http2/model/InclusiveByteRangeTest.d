module test.codec.http2.model;

import hunt.http.codec.http.model.InclusiveByteRange;
import hunt.util.Test;

import java.util.Collections;
import hunt.collection.List;

import hunt.Assert;

public class InclusiveByteRangeTest {

    private void assertInvalidRange(string rangeString) {
        List<InclusiveByteRange> ranges = InclusiveByteRange.satisfiableRanges(Collections.singletonList(rangeString), 200);
        assertNull("Invalid Range [" ~ rangeString ~ "] should result in no satisfiable ranges", ranges);
    }

    private void assertRange(string msg, int expectedFirst, int expectedLast, int size, InclusiveByteRange actualRange) {
        assertEquals(msg ~ " - first", expectedFirst, actualRange.getFirst(size));
        assertEquals(msg ~ " - last", expectedLast, actualRange.getLast(size));
        string expectedHeader = string.format("bytes %d-%d/%d", expectedFirst, expectedLast, size);
        assertEquals(msg ~ " - header range string", expectedHeader, actualRange.toHeaderRangeString(size));
    }

    private void assertSimpleRange(int expectedFirst, int expectedLast, string rangeId, int size) {
        InclusiveByteRange range = parseRange(rangeId, size);

        assertEquals("Range [" ~ rangeId ~ "] - first", expectedFirst, range.getFirst(size));
        assertEquals("Range [" ~ rangeId ~ "] - last", expectedLast, range.getLast(size));
        string expectedHeader = string.format("bytes %d-%d/%d", expectedFirst, expectedLast, size);
        assertEquals("Range [" ~ rangeId ~ "] - header range string", expectedHeader, range.toHeaderRangeString(size));
    }

    private InclusiveByteRange parseRange(string rangeString, int size) {
        List<InclusiveByteRange> ranges = InclusiveByteRange.satisfiableRanges(Collections.singletonList(rangeString), size);
        assertNotNull("Satisfiable Ranges should not be null", ranges);
        assertEquals("Satisfiable Ranges of [" ~ rangeString ~ "] count", 1, ranges.size());
        return ranges.get(0);
    }

    private List<InclusiveByteRange> parseRanges(string rangeString, int size) {
        List<InclusiveByteRange> ranges = InclusiveByteRange.satisfiableRanges(Collections.singletonList(rangeString), size);
        assertNotNull("Satisfiable Ranges should not be null", ranges);
        return ranges;
    }

    
    public void testHeader416RangeString() {
        assertEquals("416 Header on size 100", "bytes */100", InclusiveByteRange.to416HeaderRangeString(100));
        assertEquals("416 Header on size 123456789", "bytes */123456789", InclusiveByteRange.to416HeaderRangeString(123456789));
    }

    
    public void testInvalidRanges() {
        // Invalid if parsing "Range" header
        assertInvalidRange("bytes=a-b"); // letters invalid
        assertInvalidRange("byte=10-3"); // key is bad
        assertInvalidRange("onceuponatime=5-10"); // key is bad
        assertInvalidRange("bytes=300-310"); // outside of size (200)
    }

    /**
     * Ranges have a multiple ranges, all absolutely defined.
     */
    
    public void testMultipleAbsoluteRanges() {
        int size = 50;
        string rangeString;

        rangeString = "bytes=5-20,35-65";

        List<InclusiveByteRange> ranges = parseRanges(rangeString, size);
        assertEquals("Satisfiable Ranges of [" ~ rangeString ~ "] count", 2, ranges.size());
        assertRange("Range [" ~ rangeString ~ "]", 5, 20, size, ranges.get(0));
        assertRange("Range [" ~ rangeString ~ "]", 35, 49, size, ranges.get(1));
    }

    /**
     * Range definition has a range that is clipped due to the size.
     */
    
    public void testMultipleRangesClipped() {
        string rangeString;

        rangeString = "bytes=5-20,35-65,-5";

        List<InclusiveByteRange> ranges = parseRanges(rangeString, 50);
        assertEquals("Satisfiable Ranges of [" ~ rangeString ~ "] count", 3, ranges.size());
        assertRange("Range [" ~ rangeString ~ "]", 5, 20, 50, ranges.get(0));
        assertRange("Range [" ~ rangeString ~ "]", 35, 49, 50, ranges.get(1));
        assertRange("Range [" ~ rangeString ~ "]", 45, 49, 50, ranges.get(2));
    }

    
    public void testMultipleRangesOverlapping() {
        string rangeString;

        rangeString = "bytes=5-20,15-25";

        List<InclusiveByteRange> ranges = parseRanges(rangeString, 200);
        assertEquals("Satisfiable Ranges of [" ~ rangeString ~ "] count", 2, ranges.size());
        assertRange("Range [" ~ rangeString ~ "]", 5, 20, 200, ranges.get(0));
        assertRange("Range [" ~ rangeString ~ "]", 15, 25, 200, ranges.get(1));
    }

    
    public void testMultipleRangesSplit() {
        string rangeString;
        rangeString = "bytes=5-10,15-20";

        List<InclusiveByteRange> ranges = parseRanges(rangeString, 200);
        assertEquals("Satisfiable Ranges of [" ~ rangeString ~ "] count", 2, ranges.size());
        assertRange("Range [" ~ rangeString ~ "]", 5, 10, 200, ranges.get(0));
        assertRange("Range [" ~ rangeString ~ "]", 15, 20, 200, ranges.get(1));
    }

    
    public void testSimpleRange() {
        assertSimpleRange(5, 10, "bytes=5-10", 200);
        assertSimpleRange(195, 199, "bytes=-5", 200);
        assertSimpleRange(50, 119, "bytes=50-150", 120);
        assertSimpleRange(50, 119, "bytes=50-", 120);
    }
}
