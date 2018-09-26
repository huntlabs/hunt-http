module hunt.http.codec.http.model.AcceptMIMEType;

import hunt.util.common;

/**
 * 
 */
enum AcceptMIMEMatchType {
    PARENT, CHILD, ALL, EXACT
}


/**
 * 
 */
class AcceptMIMEType {
    private string parentType;
    private string childType;
    private float quality = 1.0f;
    private AcceptMIMEMatchType matchType;

    string getParentType() {
        return parentType;
    }

    void setParentType(string parentType) {
        this.parentType = parentType;
    }

    string getChildType() {
        return childType;
    }

    void setChildType(string childType) {
        this.childType = childType;
    }

    float getQuality() {
        return quality;
    }

    void setQuality(float quality) {
        this.quality = quality;
    }

    AcceptMIMEMatchType getMatchType() {
        return matchType;
    }

    void setMatchType(AcceptMIMEMatchType matchType) {
        this.matchType = matchType;
    }

    override bool opEquals(Object o) {
        if (this is o) return true;
        AcceptMIMEType that = cast(AcceptMIMEType) o;
        if(that is null)  return false;

        return parentType == that.parentType &&
                childType == that.childType;
    }

    override size_t toHash() @trusted nothrow {
        return hashCode(parentType, childType);
    }

    override string toString() {
        import std.format;
        string s = parentType ~ "/" ~ childType;
        if(quality != 1.0f) 
            s = s ~ format("; q=%0.1f", quality);
        return s;
    }
}
