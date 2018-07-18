//
//  ========================================================================
//  Copyright (c) 1995-2017 Mort Bay Consulting Pty. Ltd.
//  ------------------------------------------------------------------------
//  All rights reserved. This program and the accompanying materials
//  are made available under the terms of the Eclipse Public License v1.0
//  and Apache License v2.0 which accompanies this distribution.
//
//      The Eclipse Public License is available at
//      http://www.eclipse.org/legal/epl-v10.html
//
//      The Apache License v2.0 is available at
//      http://www.opensource.org/licenses/apache2.0.php
//
//  You may elect to redistribute this code under either of these licenses.
//  ========================================================================
//

module hunt.http.codec.http.model.InclusiveByteRange;


import kiss.logger;

import hunt.util.exception;
import hunt.util.string;

import hunt.container.List;
import hunt.container.ArrayList;

import std.conv;
import std.format;
import std.string;


/**
 * Byte range inclusive of end points.
 * &lt;PRE&gt;
 * parses the following types of byte ranges:
 * bytes=100-499
 * bytes=-300
 * bytes=100-
 * bytes=1-2,2-3,6-,-2
 * given an entity length, converts range to string
 * bytes 100-499/500
 * &lt;/PRE&gt;
 * Based on RFC2616 3.12, 14.16, 14.35.1, 14.35.2
 * And yes the spec does strangely say that while 10-20, is bytes 10 to 20 and 10- is bytes 10 until the end that -20 IS NOT bytes 0-20, but the last 20 bytes of the content.
 *
 * @version $version$
 */
class InclusiveByteRange {
    

    long first = 0;
    long last = 0;

    this(long first, long last) {
        this.first = first;
        this.last = last;
    }

    long getFirst() {
        return first;
    }

    long getLast() {
        return last;
    }

    /**
     * @param headers Enumeration of Range header fields.
     * @param size    Size of the resource.
     * @return LazyList of satisfiable ranges
     */
    static List!InclusiveByteRange satisfiableRanges(List!string headers, long size) {
        Object satRanges = null;

        // walk through all Range headers
        bool isContinue = false;
        do{
            isContinue = false;
            foreach (string header ; headers) {
                StringTokenizer tok = new StringTokenizer(header, "=,", false);
                string t = null;
                try {
                    // read all byte ranges for this header 
                    while (tok.hasMoreTokens()) {
                        try {
                            t = tok.nextToken().strip();

                            long first = -1;
                            long last = -1;
                            int d = cast(int)t.indexOf("-");
                            if (d < 0 || t.indexOf("-", d + 1) >= 0) {
                                if ("bytes" == (t))
                                    continue;
                                warningf("Bad range format: %s", t);
                                isContinue = true;
                                break;
                            } else if (d == 0) {
                                if (d + 1 < t.length)
                                    last = to!long(t.substring(d + 1).strip());
                                else {
                                    warningf("Bad range format: %s", t);
                                    continue;
                                }
                            } else if (d + 1 < t.length) {
                                first = to!long(t.substring(0, d).strip());
                                last = to!long(t.substring(d + 1).strip());
                            } else
                                first = to!long(t.substring(0, d).strip());

                            if (first == -1 && last == -1)
                            {
                                isContinue = true;
                                break;
                            }

                            if (first != -1 && last != -1 && (first > last))
                            {
                                isContinue = true;
                                break;
                            }

                            if (first < size) {
                                InclusiveByteRange range = new InclusiveByteRange(first, last);
                                satRanges = LazyList.add(satRanges, range);
                            }
                        } catch (NumberFormatException e) {
                            warningf("Bad range format: %s", t);
                            continue;
                        }
                    }
                } catch (Exception e) {
                    warningf("Bad range format: %s", t);
                }
            }


        } while(isContinue);
        return LazyList.getList!(InclusiveByteRange)(satRanges, true);
    }

    long getFirst(long size) {
        if (first < 0) {
            long tf = size - last;
            if (tf < 0)
                tf = 0;
            return tf;
        }
        return first;
    }

    long getLast(long size) {
        if (first < 0)
            return size - 1;

        if (last < 0 || last >= size)
            return size - 1;
        return last;
    }

    long getSize(long size) {
        return getLast(size) - getFirst(size) + 1;
    }

    string toHeaderRangeString(long size) {
        StringBuilder sb = new StringBuilder(40);
        sb.append("bytes ");
        sb.append(getFirst(size).to!string);
        sb.append('-');
        sb.append(getLast(size).to!string);
        sb.append("/");
        sb.append(to!string(size));
        return sb.toString();
    }

    static string to416HeaderRangeString(long size) {
        StringBuilder sb = new StringBuilder(40);
        sb.append("bytes */");
        sb.append(to!string(size));
        return sb.toString();
    }

    override
    string toString() {
        return format("%d:%d", first, last);
    }

}



