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

module test.codec.http2.model;

import hunt.http.codec.http.encode.UrlEncoded;
import hunt.http.utils.collection.MultiMap;
import hunt.http.utils.lang.Utf8Appendable;
import hunt.util.Rule;
import hunt.util.Test;
import hunt.util.rules.ExpectedException;
import hunt.util.runner.RunWith;
import hunt.util.runners.Parameterized;

import java.nio.charset.Charset;
import hunt.collection.ArrayList;
import hunt.collection.List;

import java.nio.charset.StandardCharsets.UTF_8;


public class UrlEncodedInvalidEncodingTest {

    @Rule
    public ExpectedException expectedException = ExpectedException.none();

    @Parameterized.Parameters(name = "{1} | {0}")
    public static List<Object[]> data() {
        ArrayList<Object[]> data = new ArrayList<>();

        data.add(new Object[]{"Name=xx%zzyy", UTF_8, IllegalArgumentException.class});
        data.add(new Object[]{"Name=%FF%FF%FF", UTF_8, Utf8Appendable.NotUtf8Exception.class});
        data.add(new Object[]{"Name=%EF%EF%EF", UTF_8, Utf8Appendable.NotUtf8Exception.class});
        data.add(new Object[]{"Name=%E%F%F", UTF_8, IllegalArgumentException.class});
        data.add(new Object[]{"Name=x%", UTF_8, Utf8Appendable.NotUtf8Exception.class});
        data.add(new Object[]{"Name=x%2", UTF_8, Utf8Appendable.NotUtf8Exception.class});
        data.add(new Object[]{"Name=xxx%", UTF_8, Utf8Appendable.NotUtf8Exception.class});
        data.add(new Object[]{"name=X%c0%afZ", UTF_8, Utf8Appendable.NotUtf8Exception.class});
        return data;
    }

    @Parameterized.Parameter(0)
    public string inputString;

    @Parameterized.Parameter(1)
    public Charset charset;

    @Parameterized.Parameter(2)
    public Class<? extends Throwable> expectedThrowable;

    
    public void testDecode() {
        UrlEncoded url_encoded = new UrlEncoded();
        expectedException.expect(expectedThrowable);
        url_encoded.decode(inputString, charset);
    }

    
    public void testDecodeUtf8ToMap() {
        MultiMap<string> map = new MultiMap<>();
        expectedException.expect(expectedThrowable);
        UrlEncoded.decodeUtf8To(inputString, map);
    }

    
    public void testDecodeTo() {
        MultiMap<string> map = new MultiMap<>();
        expectedException.expect(expectedThrowable);
        UrlEncoded.decodeTo(inputString, map, charset);
    }
}
