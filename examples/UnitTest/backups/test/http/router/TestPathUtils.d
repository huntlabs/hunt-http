module test.http.router;

import hunt.http.server.http.router.utils.PathUtils;
import hunt.util.Assert;
import hunt.util.Test;

import hunt.container.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;



/**
 * 
 */
public class TestPathUtils {

    
    public void test() {
        List<string> paths = PathUtils.split("/app/index/");
        Assert.assertThat(paths.size(), is(2));
        Assert.assertThat(paths.get(0), is("app"));
        Assert.assertThat(paths.get(1), is("index"));

        paths = PathUtils.split("/app/index");
        Assert.assertThat(paths.size(), is(2));
        Assert.assertThat(paths.get(0), is("app"));
        Assert.assertThat(paths.get(1), is("index"));
    }

    public static void main(string[] args) {
        string line = "This order was placed for QT3000! OK?";
        Pattern pattern = Pattern.compile("(.*?)(\\d+)(.*)");
        Matcher matcher = pattern.matcher(line);
        writeln(matcher.matches());
        matcher = pattern.matcher(line);
        while (matcher.find()) {
            writeln(matcher.groupCount());
            writeln("group 1: " ~ matcher.group(1));
            writeln("group 2: " ~ matcher.group(2));
            writeln("group 3: " ~ matcher.group(3));
        }
    }
}
