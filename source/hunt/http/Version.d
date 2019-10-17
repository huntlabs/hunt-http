module hunt.http.Version;

enum string Version = "0.4.0";

enum string X_POWERED_BY_VALUE = "Hunt " ~ Version;
enum string SERVER_VALUE = "Hunt " ~ Version;