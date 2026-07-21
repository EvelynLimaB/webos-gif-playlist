// webOS 4 / Chromium 53 compatible platform adapter.
var APP_DIR = window.location.pathname.replace(/\/[^/]+$/, "");
var MANAGER_PATH = APP_DIR + "/assets/manager.sh";
var HOMEBREW_SERVICE = "luna://org.webosbrew.hbchannel.service";
var SERVICE_TIMEOUT_MS = 180000;
var UPDATE_TIMEOUT_MS = 600000;

function WebOSService() {}

WebOSService.prototype.luna = function(service, params) {
    return new Promise(function(resolve, reject) {
        var bridge;
        var settled = false;
        var timeout;

        function finish(callback, value) {
            if (settled) {
                return;
            }
            settled = true;
            clearTimeout(timeout);
            callback(value);
        }

        if (typeof PalmServiceBridge === "undefined") {
            reject("PalmServiceBridge is unavailable. Run this app on a rooted webOS TV.");
            return;
        }

        bridge = new PalmServiceBridge();
        timeout = setTimeout(function() {
            finish(reject, "The TV service did not respond within three minutes.");
        }, SERVICE_TIMEOUT_MS);

        bridge.onservicecallback = function(message) {
            var response;
            var errorText;
            try {
                response = JSON.parse(message);
            } catch (error) {
                finish(reject, "Invalid service response: " + message);
                return;
            }

            if (response.returnValue) {
                finish(resolve, response);
            } else {
                errorText = response.errorText || "Service call failed";
                if (response.stderrString && errorText.indexOf(response.stderrString) === -1) {
                    errorText += "\n" + response.stderrString;
                }
                finish(reject, errorText);
            }
        };

        try {
            bridge.call(service, JSON.stringify(params || {}));
        } catch (error) {
            finish(reject, error.message || String(error));
        }
    });
};

WebOSService.prototype.subscribe = function(service, params, onResponse) {
    return new Promise(function(resolve, reject) {
        var bridge;
        var settled = false;
        var timeout;
        var payload = params || {};

        function cancelBridge() {
            try {
                if (bridge && typeof bridge.cancel === "function") {
                    bridge.cancel();
                }
            } catch (ignored) {
                return;
            }
        }

        function finish(callback, value) {
            if (settled) {
                return;
            }
            settled = true;
            clearTimeout(timeout);
            cancelBridge();
            callback(value);
        }

        if (typeof PalmServiceBridge === "undefined") {
            reject("PalmServiceBridge is unavailable. Run this app on a rooted webOS TV.");
            return;
        }

        payload.subscribe = true;
        bridge = new PalmServiceBridge();
        timeout = setTimeout(function() {
            finish(reject, "The update service did not finish within ten minutes.");
        }, UPDATE_TIMEOUT_MS);

        bridge.onservicecallback = function(message) {
            var response;
            try {
                response = JSON.parse(message);
            } catch (error) {
                finish(reject, "Invalid update service response: " + message);
                return;
            }

            if (response.returnValue === false) {
                finish(reject, response.errorText || "Update installation failed.");
                return;
            }

            if (onResponse) {
                try {
                    onResponse(response);
                } catch (ignored) {
                    // Presentation callbacks must not interrupt installation.
                }
            }

            if (response.finished) {
                finish(resolve, response);
            }
        };

        try {
            bridge.call(service, JSON.stringify(payload));
        } catch (error) {
            finish(reject, error.message || String(error));
        }
    });
};

WebOSService.prototype.fetchJson = function(url) {
    return new Promise(function(resolve, reject) {
        var request = new XMLHttpRequest();
        var completed = false;

        function finish(callback, value) {
            if (completed) {
                return;
            }
            completed = true;
            callback(value);
        }

        request.open("GET", url, true);
        request.timeout = 30000;
        request.onreadystatechange = function() {
            var parsed;
            if (request.readyState !== 4) {
                return;
            }
            if (request.status < 200 || request.status >= 300) {
                finish(reject, "Update manifest request failed with HTTP " + request.status + ".");
                return;
            }
            try {
                parsed = JSON.parse(request.responseText);
            } catch (error) {
                finish(reject, "The update manifest is not valid JSON.");
                return;
            }
            finish(resolve, parsed);
        };
        request.onerror = function() {
            finish(reject, "Could not reach the update server.");
        };
        request.ontimeout = function() {
            finish(reject, "The update check timed out.");
        };
        try {
            request.send();
        } catch (error) {
            finish(reject, error.message || String(error));
        }
    });
};

WebOSService.prototype.exec = function(command) {
    return this.luna(HOMEBREW_SERVICE + "/exec", {
        command: command
    }).then(function(response) {
        return (response.stdoutString || "") + (response.stderrString || "");
    });
};

WebOSService.prototype.manager = function(argumentsText) {
    return this.exec('sh "' + MANAGER_PATH + '" ' + argumentsText);
};

WebOSService.prototype.init = function() {
    return this.manager("init");
};

WebOSService.prototype.preflight = function() {
    return this.manager("preflight");
};

WebOSService.prototype.status = function() {
    return this.manager("status");
};

WebOSService.prototype.list = function() {
    return this.manager("list");
};

WebOSService.prototype.addUrl = function(url) {
    var encoded;

    if (typeof url !== "string" || !/^https?:\/\//i.test(url)) {
        return Promise.reject("Enter a direct http:// or https:// image URL.");
    }
    if (url.length > 8192 || /[\x00-\x1F\x7F]/.test(url)) {
        return Promise.reject("The URL is too long or contains control characters.");
    }

    try {
        encoded = window.btoa(unescape(encodeURIComponent(url)));
    } catch (error) {
        return Promise.reject("The URL could not be encoded.");
    }

    if (!/^[A-Za-z0-9+/=]+$/.test(encoded)) {
        return Promise.reject("The encoded URL was rejected.");
    }

    return this.manager("add '" + encoded + "'");
};

WebOSService.prototype.remove = function(id) {
    if (!/^[A-Za-z0-9._-]+$/.test(id)) {
        return Promise.reject("Invalid item id.");
    }
    return this.manager("remove '" + id + "'");
};

WebOSService.prototype.move = function(id, direction) {
    if (!/^[A-Za-z0-9._-]+$/.test(id)) {
        return Promise.reject("Invalid item id.");
    }
    if (direction !== "up" && direction !== "down") {
        return Promise.reject("Invalid direction.");
    }
    return this.manager("move '" + id + "' " + direction);
};

WebOSService.prototype.setOption = function(key, value) {
    var validators = {
        mode: /^(ordered|shuffle)$/,
        duration: /^\d{5,6}$/,
        fit: /^(crop|fit|stretch)$/,
        filter: /^(smooth|pixel)$/
    };

    if (!validators[key] || !validators[key].test(String(value))) {
        return Promise.reject("Invalid setting.");
    }

    return this.manager("set " + key + " '" + value + "'");
};

WebOSService.prototype.applyTemporary = function() {
    return this.manager("apply");
};

WebOSService.prototype.enable = function() {
    return this.manager("enable");
};

WebOSService.prototype.disable = function() {
    return this.manager("disable");
};

WebOSService.prototype.reset = function() {
    return this.manager("reset");
};

WebOSService.prototype.getInstalledAppInfo = function() {
    return this.luna(HOMEBREW_SERVICE + "/getAppInfo", {
        id: UpdatePolicy.APP_ID
    }).then(function(response) {
        if (!response.appInfo || response.appInfo.id !== UpdatePolicy.APP_ID) {
            throw new Error("Homebrew Channel could not read the installed application version.");
        }
        return response.appInfo;
    });
};

WebOSService.prototype.fetchUpdateManifest = function() {
    var separator = UpdatePolicy.MANIFEST_URL.indexOf("?") === -1 ? "?" : "&";
    return this.fetchJson(UpdatePolicy.MANIFEST_URL + separator + "cache=" + String(Date.now()));
};

WebOSService.prototype.installUpdate = function(manifest, onProgress) {
    var verified;
    try {
        verified = UpdatePolicy.validateManifest(manifest);
    } catch (error) {
        return Promise.reject(error.message || String(error));
    }

    return this.subscribe(HOMEBREW_SERVICE + "/install", {
        ipkUrl: verified.ipkUrl,
        ipkHash: verified.ipkHash.sha256,
        id: verified.id,
        subscribe: true
    }, onProgress);
};

WebOSService.prototype.triggerScreensaver = function() {
    return this.exec(
        "luna-send -n 1 luna://com.webos.applicationManager/launch " +
        "'{\"id\":\"com.webos.app.home\"}' && sleep 3 && " +
        "luna-send -n 1 luna://com.webos.service.tvpower/power/turnOnScreenSaver '{}'"
    );
};

WebOSService.prototype.testScreensaver = function() {
    var self = this;
    return this.applyTemporary().then(function() {
        return self.triggerScreensaver();
    });
};
