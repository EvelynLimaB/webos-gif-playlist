// webOS 4 / Chromium 53 compatible update policy.
var UpdatePolicy = (function() {
    var APP_ID = "com.evelyn.webosgifplaylist";
    var SOURCE_URL = "https://github.com/EvelynLimaB/webos-gif-playlist";
    var MANIFEST_URL = SOURCE_URL + "/releases/latest/download/" + APP_ID + ".manifest.json";
    var AUTO_UPDATE_KEY = APP_ID + ".automaticUpdates";
    var PENDING_VERSION_KEY = APP_ID + ".pendingUpdateVersion";

    function parseVersion(version) {
        var fields;
        var index;
        var result = [];

        if (typeof version !== "string" || !/^\d+\.\d+\.\d+$/.test(version)) {
            return null;
        }

        fields = version.split(".");
        for (index = 0; index < fields.length; index += 1) {
            result.push(parseInt(fields[index], 10));
        }
        return result;
    }

    function compareVersions(left, right) {
        var leftParts = parseVersion(left);
        var rightParts = parseVersion(right);
        var index;

        if (!leftParts || !rightParts) {
            throw new Error("Invalid application version.");
        }

        for (index = 0; index < 3; index += 1) {
            if (leftParts[index] < rightParts[index]) {
                return -1;
            }
            if (leftParts[index] > rightParts[index]) {
                return 1;
            }
        }
        return 0;
    }

    function validateManifest(manifest) {
        var version;
        var expectedIpkUrl;
        var hash;

        if (!manifest || typeof manifest !== "object" || Array.isArray(manifest)) {
            throw new Error("The update manifest is not an object.");
        }
        if (manifest.id !== APP_ID) {
            throw new Error("The update manifest belongs to another application.");
        }
        if (manifest.type !== "web") {
            throw new Error("The update manifest has an unexpected application type.");
        }
        if (manifest.sourceUrl !== SOURCE_URL) {
            throw new Error("The update manifest has an unexpected source repository.");
        }

        version = manifest.version;
        if (!parseVersion(version)) {
            throw new Error("The update manifest contains an invalid version.");
        }

        expectedIpkUrl = SOURCE_URL + "/releases/download/v" + version + "/" + APP_ID + "_" + version + "_all.ipk";
        if (manifest.ipkUrl !== expectedIpkUrl) {
            throw new Error("The update package URL was rejected.");
        }

        hash = manifest.ipkHash && manifest.ipkHash.sha256;
        if (typeof hash !== "string" || !/^[A-Fa-f0-9]{64}$/.test(hash)) {
            throw new Error("The update manifest does not contain a valid SHA-256 hash.");
        }

        return {
            id: APP_ID,
            version: version,
            type: "web",
            sourceUrl: SOURCE_URL,
            ipkUrl: expectedIpkUrl,
            ipkHash: {
                sha256: hash.toLowerCase()
            }
        };
    }

    function getStoredBoolean(storage, key) {
        try {
            return !!storage && storage.getItem(key) === "yes";
        } catch (ignored) {
            return false;
        }
    }

    function setStoredBoolean(storage, key, enabled) {
        try {
            if (storage) {
                storage.setItem(key, enabled ? "yes" : "no");
            }
        } catch (ignored) {
            return false;
        }
        return true;
    }

    function getStoredText(storage, key) {
        try {
            return storage ? (storage.getItem(key) || "") : "";
        } catch (ignored) {
            return "";
        }
    }

    function setStoredText(storage, key, value) {
        try {
            if (storage) {
                if (value) {
                    storage.setItem(key, value);
                } else {
                    storage.removeItem(key);
                }
            }
        } catch (ignored) {
            return false;
        }
        return true;
    }

    return {
        APP_ID: APP_ID,
        SOURCE_URL: SOURCE_URL,
        MANIFEST_URL: MANIFEST_URL,
        compareVersions: compareVersions,
        isNewer: function(installedVersion, availableVersion) {
            return compareVersions(installedVersion, availableVersion) < 0;
        },
        validateManifest: validateManifest,
        automaticUpdatesEnabled: function(storage) {
            return getStoredBoolean(storage, AUTO_UPDATE_KEY);
        },
        setAutomaticUpdates: function(storage, enabled) {
            return setStoredBoolean(storage, AUTO_UPDATE_KEY, enabled);
        },
        pendingVersion: function(storage) {
            return getStoredText(storage, PENDING_VERSION_KEY);
        },
        setPendingVersion: function(storage, version) {
            return setStoredText(storage, PENDING_VERSION_KEY, version);
        }
    };
}());
