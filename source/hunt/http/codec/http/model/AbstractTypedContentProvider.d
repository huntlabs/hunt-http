module hunt.http.codec.http.model.AbstractTypedContentProvider;

import hunt.http.codec.http.model.ContentProvider;


abstract class AbstractTypedContentProvider : ContentProvider.Typed {
    private string contentType;

    protected this(string contentType) {
        this.contentType = contentType;
    }

    override
    string getContentType() {
        return contentType;
    }
}
