module test.codec.http2.model;


import hunt.Assert.assertNull;
import hunt.Assert.assertThat;

import java.util.Arrays;
import hunt.collection.List;

import hunt.util.Test;
import hunt.util.runner.RunWith;
import hunt.util.runners.Parameterized;
import hunt.util.runners.Parameterized.Parameter;
import hunt.util.runners.Parameterized.Parameters;

import hunt.http.codec.http.model.HostPort;


public class HostPortTest {
	@Parameters(name="{0}")
    public static List<string[]> testCases()
    {
        string data[][] = new string[][] { 
            {"host","host",null},
            {"host:80","host","80"},
            {"10.10.10.1","10.10.10.1",null},
            {"10.10.10.1:80","10.10.10.1","80"},
            {"[0::0::0::1]","[0::0::0::1]",null},
            {"[0::0::0::1]:80","[0::0::0::1]","80"},

            {null,null,null},
            {"host:",null,null},
            {"",null,null},
            {":80",null,"80"},
            {"127.0.0.1:",null,null},
            {"[0::0::0::0::1]:",null,null},
            {"host:xxx",null,null},
            {"127.0.0.1:xxx",null,null},
            {"[0::0::0::0::1]:xxx",null,null},
            {"host:-80",null,null},
            {"127.0.0.1:-80",null,null},
            {"[0::0::0::0::1]:-80",null,null},
        };
        return Arrays.asList(data);
    }

	@Parameter(0)
	public string _authority;

	@Parameter(1)
	public string _expectedHost;

	@Parameter(2)
	public string _expectedPort;

	
	public void test() {
		try {
			HostPort hostPort = new HostPort(_authority);
			assertThat(hostPort.getHost(), is(_expectedHost));

			if (_expectedPort == null)
				assertThat(hostPort.getPort(), is(0));
			else
				assertThat(hostPort.getPort(), is(Integer.valueOf(_expectedPort)));
		} catch (Exception e) {
			assertNull(_expectedHost);
		}
	}

}
