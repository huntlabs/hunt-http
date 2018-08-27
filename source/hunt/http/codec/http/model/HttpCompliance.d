module hunt.http.codec.http.model.HttpCompliance;

import hunt.logging;

import hunt.http.codec.http.model.HttpComplianceSection;

import hunt.container.HashMap;
import hunt.container.Map;

import std.algorithm;
import std.array;
import std.string;

/**
 * HTTP compliance modes for Jetty HTTP parsing and handling.
 * A Compliance mode consists of a set of {@link HttpComplianceSection}s which are applied
 * when the mode is enabled.
 * <p>
 * Currently the set of modes is an enum and cannot be dynamically extended, but future major releases may convert this
 * to a class. To modify modes there are four custom modes that can be modified by setting the property
 * <code>org.eclipse.jetty.http.HttpCompliance.CUSTOMn</code> (where 'n' is '0', '1', '2' or '3'), to a comma separated
 * list of sections.  The list should start with one of the following strings:<dl>
 * <dt>0</dt><dd>No {@link HttpComplianceSection}s</dd>
 * <dt>*</dt><dd>All {@link HttpComplianceSection}s</dd>
 * <dt>RFC2616</dt><dd>The set of {@link HttpComplianceSection}s application to https://tools.ietf.org/html/rfc2616,
 * but not https://tools.ietf.org/html/rfc7230</dd>
 * <dt>RFC7230</dt><dd>The set of {@link HttpComplianceSection}s application to https://tools.ietf.org/html/rfc7230</dd>
 * </dl>
 * The remainder of the list can contain then names of {@link HttpComplianceSection}s to include them in the mode, or prefixed
 * with a '-' to exclude thm from the mode.    Note that Jetty's modes may have some historic minor differences from the strict
 * RFC compliance, for example the <code>RFC2616_LEGACY</code> HttpCompliance is defined as
 * <code>RFC2616,-FIELD_COLON,-METHOD_CASE_SENSITIVE</code>.
 * <p>
 * Note also that the {@link EnumSet} return by {@link HttpCompliance#sections()} is mutable, so that modes may
 * be altered in code and will affect all usages of the mode.
 */
class HttpCompliance // TODO in Jetty-10 convert this enum to a class so that extra custom modes can be defined dynamically
{
    /**
     * A Legacy compliance mode to match jetty's behavior prior to RFC2616 and RFC7230. It only
     * contains {@link HttpComplianceSection#METHOD_CASE_SENSITIVE}
     */
    __gshared HttpCompliance LEGACY; 

    /**
     * The legacy RFC2616 support, which incorrectly excludes
     * {@link HttpComplianceSection#METHOD_CASE_SENSITIVE}, {@link HttpComplianceSection#FIELD_COLON}
     */
    __gshared HttpCompliance RFC2616_LEGACY;

    /**
     * The strict RFC2616 support mode
     */
    __gshared HttpCompliance RFC2616;

    /**
     * Jetty's current RFC7230 support, which incorrectly excludes  {@link HttpComplianceSection#METHOD_CASE_SENSITIVE}
     */
    __gshared HttpCompliance RFC7230_LEGACY;

    /**
     * The RFC7230 support mode
     */
    __gshared HttpCompliance RFC7230;

    // /**
    //  * Custom compliance mode that can be defined with System property <code>org.eclipse.jetty.http.HttpCompliance.CUSTOM0</code>
    //  */
    // deprecated("")
    // CUSTOM0(sectionsByProperty("CUSTOM0")),
    // /**
    //  * Custom compliance mode that can be defined with System property <code>org.eclipse.jetty.http.HttpCompliance.CUSTOM1</code>
    //  */
    // deprecated("")
    // CUSTOM1(sectionsByProperty("CUSTOM1")),
    // /**
    //  * Custom compliance mode that can be defined with System property <code>org.eclipse.jetty.http.HttpCompliance.CUSTOM2</code>
    //  */
    // deprecated("")
    // CUSTOM2(sectionsByProperty("CUSTOM2")),
    // /**
    //  * Custom compliance mode that can be defined with System property <code>org.eclipse.jetty.http.HttpCompliance.CUSTOM3</code>
    //  */
    // deprecated("")
    // CUSTOM3(sectionsByProperty("CUSTOM3"));

    // static string VIOLATIONS_ATTR = "org.eclipse.jetty.http.compliance.violations";


    // private static HttpComplianceSection[] sectionsByProperty(string property) {
    //     string s = System.getProperty(HttpCompliance.class.getName() + property);
    //     return sectionsBySpec(s == null ? "*" : s);
    // }

    static HttpComplianceSection[] sectionsBySpec(string spec) {
        HttpComplianceSection[] sections;
        string[] elements = spec.split(",").map!(a => strip(a)).array;
        int i = 0;

        switch (elements[i]) {
            case "0":
                sections = [];
                i++;
                break;

            case "*":
                i++;
                sections = [HttpComplianceSection.CASE_INSENSITIVE_FIELD_VALUE_CACHE, HttpComplianceSection.FIELD_COLON, 
                            HttpComplianceSection.FIELD_NAME_CASE_INSENSITIVE, HttpComplianceSection.NO_WS_AFTER_FIELD_NAME,
                            HttpComplianceSection.NO_FIELD_FOLDING, HttpComplianceSection.NO_HTTP_0_9];
                break;

            case "RFC2616":
                sections = [HttpComplianceSection.CASE_INSENSITIVE_FIELD_VALUE_CACHE, HttpComplianceSection.FIELD_COLON,
                            HttpComplianceSection.FIELD_NAME_CASE_INSENSITIVE, HttpComplianceSection.NO_WS_AFTER_FIELD_NAME];
                i++;
                break;

            case "RFC7230":
                i++;
                sections = [HttpComplianceSection.CASE_INSENSITIVE_FIELD_VALUE_CACHE, HttpComplianceSection.FIELD_COLON, 
                            HttpComplianceSection.FIELD_NAME_CASE_INSENSITIVE, HttpComplianceSection.NO_WS_AFTER_FIELD_NAME,
                            HttpComplianceSection.NO_FIELD_FOLDING, HttpComplianceSection.NO_HTTP_0_9];
                break;

            default:
                sections = [];
                break;
        }

        while (i < elements.length) {
            string element = elements[i++];
            bool exclude = element.startsWith("-");
            if (exclude)
                element = element[1..$];
            HttpComplianceSection section = HttpComplianceSection.valueOf(element);
            if (section == HttpComplianceSection.Null) {
                warningf("Unknown section '" ~ element ~ "' in HttpCompliance spec: " ~ spec);
                continue;
            }
            if (exclude)
                sections = sections.remove!(x => x == section)();
            else
                sections ~= (section);

        }

        return sections;
    }

    private __gshared Map!(HttpComplianceSection, HttpCompliance) __required; 

    __gshared HttpCompliance[] values;

    shared static this() {

        LEGACY = new HttpCompliance(sectionsBySpec("0,METHOD_CASE_SENSITIVE"));
        RFC2616_LEGACY = new HttpCompliance(sectionsBySpec("RFC2616,-FIELD_COLON,-METHOD_CASE_SENSITIVE"));
        RFC2616 = new HttpCompliance(sectionsBySpec("RFC2616"));
        RFC7230_LEGACY = new HttpCompliance(sectionsBySpec("RFC7230,-METHOD_CASE_SENSITIVE"));
        RFC7230 = new HttpCompliance(sectionsBySpec("RFC7230"));
        values ~= LEGACY;
        values ~= RFC2616_LEGACY;
        values ~= RFC2616;
        values ~= RFC7230_LEGACY;
        values ~= RFC7230;

        __required = new HashMap!(HttpComplianceSection, HttpCompliance)();
        // LEGACY = new HttpCompliance(sectionsBySpec("0,METHOD_CASE_SENSITIVE"));
        // LEGACY = new HttpCompliance(sectionsBySpec("0,METHOD_CASE_SENSITIVE"));
        // LEGACY = new HttpCompliance(sectionsBySpec("0,METHOD_CASE_SENSITIVE"));

        __required = new HashMap!(HttpComplianceSection, HttpCompliance)();

        foreach (HttpComplianceSection section ; HttpComplianceSection.values.byValue) {
            foreach (HttpCompliance compliance ; HttpCompliance.values) {
                if (compliance.sections().canFind(section)) {
                    __required.put(section, compliance);
                    break;
                }
            }
        }
    }

    /**
     * @param section The section to query
     * @return The minimum compliance required to enable the section.
     */
    static HttpCompliance requiredCompliance(HttpComplianceSection section) {
        return __required.get(section);
    }

    private HttpComplianceSection[] _sections;

    private this(HttpComplianceSection[] sections) {
        _sections = sections;
    }

    /**
     * Get the set of {@link HttpComplianceSection}s supported by this compliance mode. This set
     * is mutable, so it can be modified. Any modification will affect all usages of the mode
     * within the same {@link ClassLoader}.
     *
     * @return The set of {@link HttpComplianceSection}s supported by this compliance mode.
     */
    HttpComplianceSection[] sections() {
        return _sections;
    }

}