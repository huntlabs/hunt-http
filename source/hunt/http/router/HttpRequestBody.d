module hunt.http.router.HttpRequestBody;

import hunt.collection.List;
import hunt.collection.Map;
import hunt.io.Common;

deprecated("Using HttpRequestBody instead.")
alias HttpBodyHandlerSPI = HttpRequestBody;

/**
 * 
 */
interface HttpRequestBody {

    string getParameter(string name);

    List!(string) getParameterValues(string name);

    Map!(string, List!(string)) getParameterMap();

    // Collection<Part> getParts();

    // Part getPart(string name);

    InputStream getInputStream();

    // BufferedReader getBufferedReader();

    string getStringBody(string charset);

    string getStringBody();

    // <T> T getJsonBody(Class<T> clazz);

    // <T> T getJsonBody(GenericTypeReference<T> typeReference);

    // JsonObject getJsonObjectBody();

    // JsonArray getJsonArrayBody();

}
