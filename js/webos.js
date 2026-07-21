// Platform adapter for the Homebrew Channel root service.
// Written for the Chromium 53-era browser used by webOS 4.x.

var APP_DIR = window.location.pathname.replace(/\/[^/]+$/, '');
var MANAGER_PATH = APP_DIR + "/assets/manager.sh";

function WebOSService() {}

WebOSService.prototype.luna = function(service, params) {
    return new Promise(function(resolve, reject) {
        if (typeof PalmServiceBridge === "undefined") {
            reject("PalmServiceBridge is unavailable. Run this app on a rooted webOS TV.");
            return;
        }

        var bridge = new PalmServiceBridge();
        bridge.onservicecallback = function(message) {
            var response;
            try {
                response = JSON.parse(message);
            } catch (error) {
                reject("Invalid service response: " + message);
                return;
            }

            if (response.returnValue) {
                resolve(response);
            } else {
                reject(response.errorText || response.stderrString || "Service call failed");
            }
        };
        bridge.call(service, JSON.stringify(params || {}));
    });
};

WebOSService.prototype.exec = function(command) {
    return this.luna("luna://org.webosbrew.hbchannel.service/exec", { command: command })
        .then(function(response) {
            return (response.stdoutString || "") + (response.stderrString || "");
        });
};

WebOSService.prototype.manager = function(argumentsString) {
    return this.exec('sh "' + MANAGER_PATH + '" ' + argumentsString);
};

WebOSService.prototype.init = function() {
    return this.manager("init");
};

WebOSService.prototype.status = function() {
    return this.manager("status");
};

WebOSService.prototype.list = function() {
    return this.manager("list");
};

WebOSService.prototype.addUrl = function(url) {
    if (typeof url !== "string" || !/^https?:\/\//i.test(url)) {
        return Promise.reject("Enter a direct http:// or https:// GIF URL.");
    }

    var encoded;
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
    if (!/^[A-Za-z0-9._-]+$/.test(id)) return Promise.reject("Invalid item id.");
    return this.manager("remove '" + id + "'");
};

WebOSService.prototype.move = function(id, direction) {
    if (!/^[A-Za-z0-9._-]+$/.test(id)) return Promise.reject("Invalid item id.");
    if (direction !== "up" && direction !== "down") return Promise.reject("Invalid direction.");
    return this.manager("move '" + id + "' " + direction);
};

WebOSService.prototype.setOption = function(key, value) {
    var allowed = {
        mode: /^(ordered|shuffle)$/,
        duration: /^\d{4,6}$/,
        fit: /^(crop|fit|stretch)$/
    };
    if (!allowed[key] || !allowed[key].test(String(value))) {
        return Promise.reject("Invalid setting.");
    }
    return this.manager("set " + key + " '" + value + "'");
};

WebOSService.prototype.enable = function() {
    return this.manager("enable");
};

WebOSService.prototype.disable = function() {
    return this.manager("disable");
};

WebOSService.prototype.uninstallOverride = function() {
    return this.manager("uninstall");
};

WebOSService.prototype.reset = function() {
    return this.manager("reset");
};

WebOSService.prototype.testScreensaver = function() {
    return this.exec(
        "luna-send -n 1 luna://com.webos.applicationManager/launch " +
        "'{\"id\":\"com.webos.app.home\"}'" +
        " && sleep 3" +
        " && luna-send -n 1 luna://com.webos.service.tvpower/power/turnOnScreenSaver '{}'"
    );
};
