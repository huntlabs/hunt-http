module hunt.http.Version;

enum string Version = "0.6";

enum string X_POWERED_BY_VALUE = "Hunt " ~ Version;
enum string SERVER_VALUE = "Hunt " ~ Version;