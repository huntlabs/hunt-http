module hunt.http.codec.http.stream.DataFrameHandler;

import hunt.http.codec.http.stream.HTTPHandler;
import hunt.http.codec.http.stream.HTTPConnection;
import hunt.http.codec.http.stream.HTTPOutputStream;

import hunt.http.codec.http.frame.DataFrame;
import hunt.http.codec.http.model.MetaData;
import hunt.util.functional;

/**
 * 
 */
abstract class DataFrameHandler {

    static void handleDataFrame(DataFrame dataFrame, Callback callback,
                                 MetaData.Request request, MetaData.Response response,
                                 HTTPOutputStream output, HTTPConnection connection,
                                 HTTPHandler httpHandler) {
        try {
            httpHandler.content(dataFrame.getData(), request, response, output, connection);
            if (dataFrame.isEndStream()) {
                httpHandler.contentComplete(request, response, output, connection);
                httpHandler.messageComplete(request, response, output, connection);
            }
            callback.succeeded();
        } catch (Exception t) {
            callback.failed(t);
        }
    }
}
