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

module test.codec.websocket.utils;

import hunt.http.codec.websocket.utils.QuoteUtil;
import hunt.util.Assert;
import hunt.util.Test;
import hunt.util.runner.RunWith;
import hunt.util.runners.Parameterized;
import hunt.util.runners.Parameterized.Parameters;

import hunt.container.ArrayList;
import java.util.Collection;
import hunt.container.List;



/**
 * Test QuoteUtil.quote(), and QuoteUtil.dequote()
 */

public class QuoteUtil_QuoteTest {
    @Parameters
    public static Collection<Object[]> data() {
        // The various quoting of a string
        List<Object[]> data = new ArrayList<>();

        // @formatter:off
        data.add(new Object[]{"Hi", "\"Hi\""});
        data.add(new Object[]{"Hello World", "\"Hello World\""});
        data.add(new Object[]{"9.0.0", "\"9.0.0\""});
        data.add(new Object[]{"Something \"Special\"",
                "\"Something \\\"Special\\\"\""});
        data.add(new Object[]{"A Few\n\"Good\"\tMen",
                "\"A Few\\n\\\"Good\\\"\\tMen\""});
        // @formatter:on

        return data;
    }

    private string unquoted;
    private string quoted;

    public QuoteUtil_QuoteTest(string unquoted, string quoted) {
        this.unquoted = unquoted;
        this.quoted = quoted;
    }

    
    public void testDequoting() {
        string actual = QuoteUtil.dequote(quoted);
        actual = QuoteUtil.unescape(actual);
        Assert.assertThat(actual, is(unquoted));
    }

    
    public void testQuoting() {
        StringBuilder buf = new StringBuilder();
        QuoteUtil.quote(buf, unquoted);

        string actual = buf.toString();
        Assert.assertThat(actual, is(quoted));
    }
}
