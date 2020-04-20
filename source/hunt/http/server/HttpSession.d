module hunt.http.server.HttpSession;

import hunt.http.Exceptions;

import hunt.collection.HashMap;
import hunt.collection.Map;
import hunt.Exceptions;
import hunt.util.DateTime;
import hunt.util.Lifecycle;

import std.algorithm;
import std.conv;
import std.digest.sha;
import std.json;
import std.range;
import std.string;
import std.traits;
import std.variant;


enum string DefaultSessionIdName = "hunt_session";


/**
 * 
 */
class HttpSession {

    private string id;
    private long creationTime;
    private long lastAccessedTime;
    private int maxInactiveInterval;
    private JSONValue attributes;
    private bool newSession;

    string getId() {
        return id;
    }

    void setId(string id) {
        this.id = id;
    }

    long getCreationTime() {
        return creationTime;
    }

    void setCreationTime(long creationTime) {
        this.creationTime = creationTime;
    }

    long getLastAccessedTime() {
        return lastAccessedTime;
    }

    void setLastAccessedTime(long lastAccessedTime) {
        this.lastAccessedTime = lastAccessedTime;
    }

    /**
     * Get the max inactive interval. The time unit is second.
     *
     * @return The max inactive interval.
     */
    int getMaxInactiveInterval() {
        return maxInactiveInterval;
    }

    /**
     * Set the max inactive interval. The time unit is second.
     *
     * @param maxInactiveInterval The max inactive interval.
     */
    void setMaxInactiveInterval(int maxInactiveInterval) {
        this.maxInactiveInterval = maxInactiveInterval;
    }

    ref JSONValue getAttributes() {
        return attributes;
    }

    void setAttributes(ref JSONValue attributes) {
        this.attributes = attributes;
    }

    void setAttribute(T)(string name, T value) {
        this.attributes[name] = value;
    }

    T getAttribute(T=string)(string name) {
        JSONValue jv = attributes[name];
        return jv.get!T();
    }

    bool isNewSession() {
        return newSession;
    }

    void setNewSession(bool newSession) {
        this.newSession = newSession;
    }

    bool isValid() {
        long currentTime = DateTime.currentTimeMillis();
        return (currentTime - lastAccessedTime) < (maxInactiveInterval * 1000);
    }

    void set(T)(string name, T value) {
        this.attributes[name] = JSONValue(value);
    }

    T get(T = string)(string name, T defaultValue = T.init) {
        if(attributes.isNull)
            return defaultValue;

        const(JSONValue)* itemPtr = name in attributes;
        if (itemPtr is null)
            return defaultValue;
        static if (!is(T == string) && isDynamicArray!T && is(T : U[], U)) {
            U[] r;
            foreach (JSONValue jv; itemPtr.array) {
                r ~= get!U(jv);
            }
            return r;
        }
        else {
            return get!T(*itemPtr);
        }
    }

    private static T get(T = string)(JSONValue itemPtr) {
        static if (is(T == string)) {
            return itemPtr.str;
        }
        else static if (isIntegral!T) {
            return cast(T) itemPtr.integer;
        }
        else static if (isFloatingPoint!T) {
            return cast(T) itemPtr.floating;
        }
        else {
            static assert(false, "Unsupported type: " ~ typeid(T).name);
        }
    }

    void remove(string key) {
        if(attributes.isNull)
            return;

        JSONValue json;
        foreach (string _key, ref value; attributes) {
            if (_key != key) {
                json[_key] = value;
            }
        }

        attributes = json;
    }

    alias forget = remove;

    string[] keys() {
        if(attributes.isNull)
            return null;
            
        string[] ret;

        foreach (string key, ref value; attributes) {
            ret ~= key;
        }

        return ret;
    }

    /**
     * Get all of the session data.
     *
     * @return array
     */
    string[string] all() {
        if (attributes.isNull)
            return null;

        string[string] v;
        foreach (string key, ref JSONValue value; attributes) {
            if (value.type == JSONType.string)
                v[key] = value.str;
            else
                v[key] = value.toString();
        }

        return v;
    }

    /**
     * Checks if a key exists.
     *
     * @param  string|array  key
     * @return bool
     */
    bool exists(string key) {
        if (attributes.isNull)
            return false;
        const(JSONValue)* item = key in attributes;
        return item !is null;
    }

    /**
     * Checks if a key is present and not null.
     *
     * @param  string|array  key
     * @return bool
     */
    bool has(string key) {
        if (attributes.isNull)
            return false;

        auto item = key in attributes;
        if ((item !is null) && (!item.str.empty))
            return true;
        else
            return false;
    }

    /**
     * Get the value of a given key and then forget it.
     *
     * @param  string  key
     * @param  string  default
     * @return mixed
     */
    void pull(string key, string value) {
        attributes[key] = value;
    }

    /**
     * Determine if the session contains old input.
     *
     * @param  string  key
     * @return bool
     */
    bool hasOldInput(string key) {
        string old = getOldInput(key);
        return !old.empty;
    }

    /**
     * Get the requested item from the flashed input array.
     *
     * @param  string  key
     * @param  mixed   default
     * @return mixed
     */
    string[string] getOldInput(string[string] defaults = null) {
        string v = get("_old_input");
        if (v.empty)
            return defaults;
        else
            return to!(string[string])(v);
    }

    /// ditto
    string getOldInput(string key, string defaults = null) {
        string old = get("_old_input");
        string[string] v = to!(string[string])(old);
        return v.get(key, defaults);
    }

    /**
     * Replace the given session attributes entirely.
     *
     * @param  array  attributes
     * @return void
     */
    void replace(string[string] attributes) {
        this.attributes = JSONValue.init;
        put(attributes);
    }

    /**
     * Put a key / value pair or array of key / value pairs in the session.
     *
     * @param  string|array  key
     * @param  mixed       value
     * @return void
     */
    void put(T = string)(string key, T value) {
        attributes[key] = value;
    }

    /// ditto
    void put(string[string] pairs) {
        foreach (string key, string value; pairs)
            attributes[key] = value;
    }

    /**
     * Get an item from the session, or store the default value.
     *
     * @param  string  key
     * @param  \Closure  callback
     * @return mixed
     */
    string remember(string key, string value) {
        string v = this.get(key);
        if (!v.empty)
            return v;

        this.put(key, value);
        return value;
    }

    /**
     * Push a value onto a session array.
     *
     * @param  string  key
     * @param  mixed   value
     * @return void
     */
    void push(T = string)(string key, T value) {
        T[] array = this.get!(T[])(key);
        array ~= value;

        this.put(key, array);
    }

    /**
     * Flash a key / value pair to the session.
     *
     * @param  string  key
     * @param  mixed   value
     * @return void
     */
    void flash(T = string)(string key, T value) {
        this.put(key, value);
        this.push("_flash.new", key);
        this.removeFromOldFlashData([key]);
    }

    /**
     * Flash a key / value pair to the session for immediate use.
     *
     * @param  string key
     * @param  mixed value
     * @return void
     */
    void now(T = string)(string key, T value) {
        this.put(key, value);
        this.push("_flash.old", key);
    }

    /**
     * Reflash all of the session flash data.
     *
     * @return void
     */
    public void reflash() {
        this.mergeNewFlashes(this.get!(string[])("_flash.old"));
        this.put!(string[])("_flash.old", []);
    }

    /**
     * Reflash a subset of the current flash data.
     *
     * @param  array|mixed  keys
     * @return void
     */
    void keep(string[] keys...) {
        string[] ks = keys.dup;
        mergeNewFlashes(ks);
        removeFromOldFlashData(ks);
    }

    /**
     * Merge new flash keys into the new flash array.
     *
     * @param  array  keys
     * @return void
     */
    protected void mergeNewFlashes(string[] keys) {
        string[] oldKeys = this.get!(string[])("_flash.new");
        string[] values = oldKeys ~ keys;
        values = values.sort().uniq().array;

        this.put("_flash.new", values);
    }

    /**
     * Remove the given keys from the old flash data.
     *
     * @param  array  keys
     * @return void
     */
    protected void removeFromOldFlashData(string[] keys) {
        string[] olds = this.get!(string[])("_flash.old");
        string[] news = olds.remove!(x => keys.canFind(x));
        this.put("_flash.old", news);
    }

    /**
     * Flash an input array to the session.
     *
     * @param  array  value
     * @return void
     */
    void flashInput(string[string] value) {
        flash("_old_input", to!string(value));
    }

    /**
     * Flush the session data and regenerate the ID.
     *
     * @return bool
     */
    // bool invalidate()
    // {
    // 	flush();

    // 	return migrate(true);
    // }

    override bool opEquals(Object o) {
        if (this is o)
            return true;
        HttpSession that = cast(HttpSession) o;
        if (that is null)
            return false;
        return id == that.id;
    }

    override size_t toHash() @trusted nothrow {
        return hashOf(id);
    }

    static HttpSession create(string id, int maxInactiveInterval) {
        long currentTime = DateTime.currentTimeMillis();
        HttpSession session = new HttpSession();
        session.setId(id);
        session.setMaxInactiveInterval(maxInactiveInterval);
        session.setCreationTime(currentTime);
        session.setLastAccessedTime(session.getCreationTime());
        // session.setAttributes(new HashMap!(string, Object)());
        session.setNewSession(true);
        return session;
    }

    static string toJson(HttpSession session) {
        JSONValue j;
        j["CreationTime"] = session.creationTime;
        j["attr"] = session.attributes;
        return j.toString();
    }

    static HttpSession fromJson(string id, string json) {
        JSONValue j = parseJSON(json);
        long currentTime = DateTime.currentTimeMillis();
        HttpSession session = new HttpSession();
        session.setId(id);
        session.setCreationTime(j["CreationTime"].integer);
        session.setLastAccessedTime(currentTime);
        session.setNewSession(false);
        session.attributes = j["attr"];

        return session;
    }

    static string generateSessionId(string sessionName = DefaultSessionIdName) {
        SHA1 hash;
        hash.start();
        hash.put(getRandom);
        ubyte[20] result = hash.finish();
        string str = toLower(toHexString(result));

        return str;
    }
}

ubyte[] getRandom(ushort len = 64)
{
    assert(len);
    ubyte[] buffer;
    buffer.length = len;
    version(Windows){
        HCRYPTPROV hCryptProv;
        assert(CryptAcquireContext(&hCryptProv, NULL, NULL, PROV_RSA_FULL, CRYPT_VERIFYCONTEXT) != 0);
        CryptGenRandom(hCryptProv, cast(DWORD)buffer.length, buffer.ptr);
        scope(exit)CryptReleaseContext(hCryptProv, 0);
    }else version(SecureARC4Random){
        arc4random_buf(buffer.ptr, len);
    }else{
        import core.stdc.stdio : FILE, _IONBF, fopen, fclose, fread, setvbuf;
        auto file = fopen("/dev/urandom","rb");
        scope(exit)fclose(file);
        if(file is null)throw new Exception("Failed to open /dev/urandom"); 
        if(setvbuf(file, null, 0, _IONBF) != 0)throw new 
            Exception("Failed to disable buffering for random number file handle");
        if(fread(buffer.ptr, buffer.length, 1, file) != 1)throw new
            Exception("Failed to read next random number");
    }
    return buffer;
}

/**
 * 
 */
interface SessionStore : Lifecycle {

    bool contains(string key);

    bool remove(string key);

    bool put(string key, HttpSession value);

    HttpSession get(string key);

    int size();

}

/**
 * 
 */
interface HttpSessionHandler {

    HttpSession getSessionById(string id);

    HttpSession getSession();

    HttpSession getSession(bool create);

    HttpSession getAndCreateSession(int maxAge);

    int getSessionSize();

    bool removeSession();

    bool removeSessionById(string id);

    bool updateSession(HttpSession httpSession);

    bool isRequestedSessionIdFromURL();

    bool isRequestedSessionIdFromCookie();

    string getRequestedSessionId();

    string getSessionIdParameterName();
}
