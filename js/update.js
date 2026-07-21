// webOS 4 / Chromium 53 compatible update policy and controller.
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

function UpdateController(webosService) {
    this.webos = webosService;
    this.storage = window.localStorage;
    this.state = {
        installedVersion: "unknown",
        latestVersion: "unknown",
        available: false,
        automatic: UpdatePolicy.automaticUpdatesEnabled(this.storage),
        checking: false,
        installing: false,
        manifest: null,
        detail: "Checks the project's official GitHub Release manifest. Automatic installation is off by default."
    };
    this._bind();
    this.render();
}

UpdateController.prototype._bind = function() {
    var self = this;
    document.getElementById("btn-update-check").addEventListener("click", function() {
        self.check(true, false);
    });
    document.getElementById("btn-update-install").addEventListener("click", function() {
        self.install(false);
    });
    document.getElementById("btn-update-auto").addEventListener("click", function() {
        self.toggleAutomatic();
    });
};

UpdateController.prototype._errorText = function(error) {
    if (typeof error === "string") {
        return error;
    }
    if (error && error.message) {
        return error.message;
    }
    return String(error || "Unknown update error");
};

UpdateController.prototype._setGlobalStatus = function(message, type) {
    var status = document.getElementById("status");
    status.textContent = message || "";
    status.className = type || "";
};

UpdateController.prototype.render = function() {
    var installed = this.state.installedVersion || "unknown";
    var latest = this.state.latestVersion || "unknown";
    var versionText = "Installed: " + installed;
    var checkButton = document.getElementById("btn-update-check");
    var installButton = document.getElementById("btn-update-install");
    var autoButton = document.getElementById("btn-update-auto");

    if (latest !== "unknown") {
        versionText += " · Latest: " + latest;
    }
    document.getElementById("value-update-version").textContent = versionText;
    document.getElementById("update-detail").textContent = this.state.detail;

    checkButton.textContent = this.state.checking ? "Checking…" : "Check now";
    checkButton.disabled = this.state.checking || this.state.installing;

    installButton.textContent = this.state.installing ? "Installing…" : (this.state.available ? "Install " + latest : "Install update");
    installButton.disabled = !this.state.available || this.state.checking || this.state.installing;

    autoButton.textContent = "Automatic updates: " + (this.state.automatic ? "On" : "Off");
    autoButton.className = this.state.automatic ? "success" : "";
    autoButton.disabled = this.state.installing;
};

UpdateController.prototype.toggleAutomatic = function() {
    var next = !this.state.automatic;
    if (next && window.confirm && !window.confirm("Automatically install future updates from this project's verified GitHub Releases?")) {
        return;
    }

    UpdatePolicy.setAutomaticUpdates(this.storage, next);
    this.state.automatic = next;
    this.state.detail = next ?
        "Automatic updates are enabled. New verified releases install when this app opens." :
        "Automatic installation is off. The app still checks and lets you install manually.";
    this.render();

    if (next) {
        this.check(true, true);
    }
};

UpdateController.prototype.check = function(showErrors, allowAutomaticInstall) {
    var self = this;
    var pending = UpdatePolicy.pendingVersion(this.storage);

    if (this.state.checking || this.state.installing) {
        return Promise.resolve(null);
    }

    this.state.checking = true;
    this.state.detail = "Checking the official release manifest…";
    this.render();

    return Promise.all([
        this.webos.getInstalledAppInfo(),
        this.webos.fetchUpdateManifest()
    ]).then(function(results) {
        var appInfo = results[0];
        var manifest = UpdatePolicy.validateManifest(results[1]);

        self.state.installedVersion = appInfo.version || "unknown";
        self.state.latestVersion = manifest.version;
        self.state.manifest = manifest;
        self.state.available = UpdatePolicy.isNewer(self.state.installedVersion, manifest.version);
        self.state.checking = false;

        if (pending && pending === self.state.installedVersion) {
            UpdatePolicy.setPendingVersion(self.storage, "");
            self.state.detail = "Updated successfully to " + self.state.installedVersion + ".";
            self._setGlobalStatus(self.state.detail, "ok");
        } else if (self.state.available) {
            self.state.detail = "Update " + manifest.version + " is available. The package SHA-256 will be verified before installation.";
            if (showErrors) {
                self._setGlobalStatus(self.state.detail, "ok");
            }
        } else {
            self.state.detail = "You are running the latest published version.";
            if (showErrors) {
                self._setGlobalStatus(self.state.detail, "ok");
            }
        }

        self.render();
        if (self.state.available && self.state.automatic && allowAutomaticInstall) {
            return self.install(true);
        }
        return manifest;
    }).catch(function(error) {
        var message = self._errorText(error);
        self.state.checking = false;
        self.state.available = false;
        self.state.manifest = null;
        self.state.detail = "Update check unavailable: " + message;
        self.render();
        if (showErrors) {
            self._setGlobalStatus(self.state.detail, "err");
        }
        return null;
    });
};

UpdateController.prototype.install = function(automatic) {
    var self = this;
    var manifest = this.state.manifest;

    if (!manifest || !this.state.available || this.state.installing) {
        return Promise.resolve(null);
    }

    if (!automatic && window.confirm && !window.confirm(
        "Install Screensaver Playlist " + manifest.version + " now? The app may close while Homebrew Channel replaces the package."
    )) {
        return Promise.resolve(null);
    }

    this.state.installing = true;
    this.state.detail = "Preparing update " + manifest.version + "…";
    UpdatePolicy.setPendingVersion(this.storage, manifest.version);
    this.render();
    this._setGlobalStatus(this.state.detail);

    return this.webos.installUpdate(manifest, function(progress) {
        var text = progress.statusText || "Installing update…";
        if (typeof progress.progress === "number") {
            text += " " + Math.round(progress.progress) + "%";
        }
        self.state.detail = text;
        self.render();
        self._setGlobalStatus(text);
    }).then(function() {
        self.state.installing = false;
        self.state.detail = "Update installed. Reopen the app if it does not relaunch automatically.";
        self.render();
        self._setGlobalStatus(self.state.detail, "ok");
        return true;
    }).catch(function(error) {
        var message = self._errorText(error);
        UpdatePolicy.setPendingVersion(self.storage, "");
        self.state.installing = false;
        self.state.detail = "Update failed: " + message;
        self.render();
        self._setGlobalStatus(self.state.detail, "err");
        return false;
    });
};

window.addEventListener("DOMContentLoaded", function() {
    var controller = new UpdateController(new WebOSService());
    controller.check(false, true);
});
