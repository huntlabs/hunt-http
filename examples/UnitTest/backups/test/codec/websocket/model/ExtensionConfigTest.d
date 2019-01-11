module test.codec.websocket.model;

import hunt.http.codec.websocket.model.ExtensionConfig;
import hunt.Assert;
import hunt.util.Test;

import java.util.HashMap;
import java.util.Map;




public class ExtensionConfigTest {
    private void assertConfig(ExtensionConfig cfg, string expectedName, Map!(string, string) expectedParams) {
        string prefix = "ExtensionConfig";
        Assert.assertThat(prefix ~ ".Name", cfg.getName(), is(expectedName));

        prefix += ".getParameters()";
        Map!(string, string) actualParams = cfg.getParameters();
        Assert.assertThat(prefix, actualParams, notNullValue());
        Assert.assertThat(prefix ~ ".size", actualParams.size(), is(expectedParams.size()));

        for (string expectedKey : expectedParams.keySet()) {
            Assert.assertThat(prefix ~ ".containsKey(" ~ expectedKey ~ ")", actualParams.containsKey(expectedKey), is(true));

            string expectedValue = expectedParams.get(expectedKey);
            string actualValue = actualParams.get(expectedKey);

            Assert.assertThat(prefix ~ ".containsKey(" ~ expectedKey ~ ")", actualValue, is(expectedValue));
        }
    }

    
    public void testParseMuxExample() {
        ExtensionConfig cfg = ExtensionConfig.parse("mux; max-channels=4; flow-control");
        Map!(string, string) expectedParams = new HashMap<>();
        expectedParams.put("max-channels", "4");
        expectedParams.put("flow-control", null);
        assertConfig(cfg, "mux", expectedParams);
    }

    
    public void testParsePerMessageCompressExample1() {
        ExtensionConfig cfg = ExtensionConfig.parse("permessage-compress; method=foo");
        Map!(string, string) expectedParams = new HashMap<>();
        expectedParams.put("method", "foo");
        assertConfig(cfg, "permessage-compress", expectedParams);
    }

    
    public void testParsePerMessageCompressExample2() {
        ExtensionConfig cfg = ExtensionConfig.parse("permessage-compress; method=\"foo; x=10\"");
        Map!(string, string) expectedParams = new HashMap<>();
        expectedParams.put("method", "foo; x=10");
        assertConfig(cfg, "permessage-compress", expectedParams);
    }

    
    public void testParsePerMessageCompressExample3() {
        ExtensionConfig cfg = ExtensionConfig.parse("permessage-compress; method=\"foo, bar\"");
        Map!(string, string) expectedParams = new HashMap<>();
        expectedParams.put("method", "foo, bar");
        assertConfig(cfg, "permessage-compress", expectedParams);
    }

    
    public void testParsePerMessageCompressExample4() {
        ExtensionConfig cfg = ExtensionConfig.parse("permessage-compress; method=\"foo; use_x, foo\"");
        Map!(string, string) expectedParams = new HashMap<>();
        expectedParams.put("method", "foo; use_x, foo");
        assertConfig(cfg, "permessage-compress", expectedParams);
    }

    
    public void testParsePerMessageCompressExample5() {
        ExtensionConfig cfg = ExtensionConfig.parse("permessage-compress; method=\"foo; x=\\\"Hello World\\\", bar\"");
        Map!(string, string) expectedParams = new HashMap<>();
        expectedParams.put("method", "foo; x=\"Hello World\", bar");
        assertConfig(cfg, "permessage-compress", expectedParams);
    }

    
    public void testParseSimple_BasicParameters() {
        ExtensionConfig cfg = ExtensionConfig.parse("bar; baz=2");
        Map!(string, string) expectedParams = new HashMap<>();
        expectedParams.put("baz", "2");
        assertConfig(cfg, "bar", expectedParams);
    }

    
    public void testParseSimple_NoParameters() {
        ExtensionConfig cfg = ExtensionConfig.parse("foo");
        Map!(string, string) expectedParams = new HashMap<>();
        assertConfig(cfg, "foo", expectedParams);
    }
}
