module test.http.router.handler.session;

import hunt.http.$;
import hunt.http.codec.http.model.Cookie;
import hunt.http.server.http.HTTP2ServerBuilder;
import hunt.http.server.http.router.HTTPSession;
import hunt.http.server.http.router.handler.session.HTTPSessionConfiguration;
import hunt.http.server.http.router.handler.session.LocalHTTPSessionHandler;
import hunt.util.Assert;
import hunt.util.Test;
import test.http.router.handler.AbstractHTTPHandlerTest;

import hunt.container.List;
import java.util.concurrent.Phaser;



/**
 * 
 */
public class TestLocalHTTPSessionHandler extends AbstractHTTPHandlerTest {

    
    public void test() {
        int maxGetSession = 3;
        Phaser phaser = new Phaser(1 + maxGetSession);
        HTTP2ServerBuilder httpsServer = $.httpsServer();
        LocalHTTPSessionHandler sessionHandler = new LocalHTTPSessionHandler(new HTTPSessionConfiguration());
        httpsServer.router().path("*").handler(sessionHandler)
                   .router().post("/session/:name")
                   .handler(ctx -> {
                       string name = ctx.getRouterParameter("name");
                       writeln("the path param -> " ~ name);
                       Assert.assertThat(name, is("foo"));
                       HTTPSession session = ctx.getSessionNow();
                       session.getAttributes().put(name, "bar");
                       session.setMaxInactiveInterval(1);
                       ctx.updateSessionNow(session);
                       ctx.end("create session success");
                   })
                   .router().get("/session/:name")
                   .handler(ctx -> {
                       string name = ctx.getRouterParameter("name");
                       Assert.assertThat(name, is("foo"));
                       HTTPSession session = ctx.getSessionNow();
                       if (session != null) {
                           Assert.assertThat(session.getAttributes().get("foo"), is("bar"));
                           ctx.end("session value is " ~ session.getAttributes().get("foo"));
                       } else {
                           ctx.end("session is invalid");
                       }
                   })
                   .listen(host, port);

        $.httpsClient().post(uri ~ "/session/foo").submit()
         .thenApply(res -> {
             List<Cookie> cookies = res.getCookies();
             writeln(res.getStatus());
             writeln(cookies);
             writeln(res.getStringBody());
             Assert.assertThat(res.getStringBody(), is("create session success"));
             return cookies;
         })
         .thenApply(cookies -> {
             for (int i = 0; i < maxGetSession; i++) {
                 $.httpsClient().get(uri ~ "/session/foo").cookies(cookies).submit()
                  .thenAccept(res2 -> {
                      string sessionFoo = res2.getStringBody();
                      writeln(sessionFoo);
                      Assert.assertThat(sessionFoo, is("session value is bar"));
                      phaser.arrive();
                  });
             }
             return cookies;
         });

        phaser.arriveAndAwaitAdvance();
        httpsServer.stop();
        $.httpsClient().stop();
        sessionHandler.stop();
    }
}
