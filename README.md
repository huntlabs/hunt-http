[![Build Status](https://travis-ci.org/huntlabs/hunt-http.svg?branch=master)](https://travis-ci.org/huntlabs/hunt-http)

# hunt-http
Hunt-Http is a flexible performant http server and client written in D Programming Language.

## Features
| Feature | Server | Client |
|--------|--------|--------|
| HTTP 1.x | tested | tested |
| HTTP/2 | tested | tested |
| TLS 1.2 | tested | tested[1] |
| WebSocket[2] | tested | tested |
| Routing | tested | none |
| Cookie | tested | tested[3] |
| Session | tested[4] | tested |
| Form-Data[5] | tested | tested |
| X-WWW-Form | tested | tested |

**Note:**

[1] Mutual TLS supported <br>
[2] WSS untested<br>
[3] In-memory only<br>
[4] In-memory only<br>
[5] File upload and download<br>

## Simple codes

### Using hunt-http build a web server
```D
import hunt.http;

void main()
{
    auto server = HttpServer.builder()
        .setListener(8080, "0.0.0.0")
        .setHandler((RoutingContext context) {
            context.write("Hello World!");
            context.end();
        }).build();

    server.start();
}
```

### Using hunt-http build a http client
```D
import hunt.http;

import std.stdio;

void main()
{
    auto client = new HttpClient();

    auto request = new RequestBuilder().url("http://www.huntlabs.net").build();

    auto response = client.newCall(request).execute();

    if (response !is null)
    {
        writeln(response.getBody().asString());
    }
}
```

### Using hunt-http build a websocket server
```D
import hunt.http;

void main()
{
    auto server = HttpServer.builder()
        .setListener(8080, "0.0.0.0")
        .websocket("/ws", new class AbstractWebSocketMessageHandler {
            override void onText(WebSocketConnection connection, string text)
            {
                connection.sendText("Hello " ~ text);
            }
        }).build()

    server.start();
}
```


## Avaliable versions
| Name | Description | 
|--------|--------|
| HUNT_HTTP_DEBUG |  Used to log debug messages about Hunt-HTTP |
| HUNT_METRIC |  Used to enable some operations and APIs about metric |

## TODO
- [ ] Reorganizing modules
- [ ] PersistentCookieStore for HttpClient
- [ ] Benchmark

## References
- Eclipse Jetty 9.4.x, [https://github.com/eclipse/jetty.project](https://github.com/eclipse/jetty.project)
