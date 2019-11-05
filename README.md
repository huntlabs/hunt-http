[![Build Status](https://travis-ci.org/huntlabs/hunt-http.svg?branch=master)](https://travis-ci.org/huntlabs/hunt-http)

# hunt-http

## Features
| Feature | Server | Client |
|--------|--------|--------|
| HTTP 1.x | tested | tested |
| HTTP2 | tested | tested |
| TLS 1.2 | tested | tested[1] |
| WebSocket[2] | tested | tested |
| Routing | tested | none |
| Cookie | tested | tested[3] |
| Session | tested[4] | tested |
| Form-Data | tested | tested[5] |
| X-WWW-Form | tested | tested |

**Note:**

[1] Custom certificates<br>
[2] WSS untested<br>
[3] In-memory only<br>
[4] In-memory only<br>
[5] Download untested<br>


## Avaliable versions
| Name | Description | 
|--------|--------|
| HUNT_HTTP_DEBUG |  Used to log debug messages about Hunt-HTTP |
| HUNT_METRIC |  Used to enable some operations and APIs about metric |

## TODO
- [ ] Reorganizing modules
- [ ] PersistentCookieStore for HttpClient
- [ ] More unit tests

## References
- Eclipse Jetty 9.4.x, [https://github.com/eclipse/jetty.project](https://github.com/eclipse/jetty.project)
