module hunt.http.util.Completable;

import hunt.concurrency.CompletableFuture;
import hunt.concurrency.Promise;


/**
* <p>A CompletableFuture that is also a Promise.</p>
*
* @param <S> the type of the result
*/
class Completable(S) : CompletableFuture!S , Promise!S {
    override
    void succeeded(S result) {
        complete(result);
    }

    override
    void failed(Exception x) {
        completeExceptionally(x);
    }

    string id() {
        return _id;
    }

    void id(string id) { _id = id;}

    this() {
        _id = "undefined";
        super();
    }

    private string _id;
}
