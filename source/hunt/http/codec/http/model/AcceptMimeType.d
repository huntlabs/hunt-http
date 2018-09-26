module hunt.http.codec.http.model.AcceptMimeType;

import hunt.util.common;

/**
 * 
 */
enum AcceptMimeMatchType {
    PARENT, CHILD, ALL, EXACT
}


/**
 * 
 */
class AcceptMimeType {
    private string parentType;
    private string childType;
    private float quality = 1.0f;
    private AcceptMimeMatchType matchType;

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

    AcceptMimeMatchType getMatchType() {
        return matchType;
    }

    void setMatchType(AcceptMimeMatchType matchType) {
        this.matchType = matchType;
    }

    override bool opEquals(Object o) {
        if (this is o) return true;
        AcceptMimeType that = cast(AcceptMimeType) o;
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
