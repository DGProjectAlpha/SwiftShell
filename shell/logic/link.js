var NETWORK_REASON = "Quickshell 0.2 does not document a NetworkManager type. This shell does not parse connection tools and does not store Wi-Fi secrets.";
var BRIGHTNESS_REASON = "Quickshell 0.2 does not document a backlight or DDC call. This shell does not dim the picture and call that hardware brightness.";

var swiftshellLink = {
    NETWORK_REASON: NETWORK_REASON,
    BRIGHTNESS_REASON: BRIGHTNESS_REASON,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellLink;
