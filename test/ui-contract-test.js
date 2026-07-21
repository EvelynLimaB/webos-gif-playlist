"use strict";

var fs = require("fs");
var path = require("path");
var root = path.resolve(__dirname, "..");
var html = fs.readFileSync(path.join(root, "index.html"), "utf8");
var updater = fs.readFileSync(path.join(root, "js/update.js"), "utf8");
var view = fs.readFileSync(path.join(root, "js/view.js"), "utf8");
var app = fs.readFileSync(path.join(root, "js/app.js"), "utf8");
var webos = fs.readFileSync(path.join(root, "js/webos.js"), "utf8");
var ids = {};
var idPattern = /\bid="([A-Za-z0-9_-]+)"/g;
var match;

while ((match = idPattern.exec(html)) !== null) {
    if (ids[match[1]]) {
        throw new Error("duplicate HTML id: " + match[1]);
    }
    ids[match[1]] = true;
}

var lookupPattern = /getElementById\("([A-Za-z0-9_-]+)"\)/g;
while ((match = lookupPattern.exec(view + "\n" + updater)) !== null) {
    if (!ids[match[1]]) {
        throw new Error("JavaScript references missing HTML id: " + match[1]);
    }
}

["onAdd", "onRemove", "onMove", "onMode", "onFit", "onFilter", "onDuration", "onRefresh", "onCheck", "onApply", "onEnable", "onTest", "onDisable", "onReset"].forEach(function(name) {
    if (view.indexOf("View.prototype." + name) === -1) {
        throw new Error("missing view callback: " + name);
    }
    if (app.indexOf("this.view." + name) === -1) {
        throw new Error("app does not wire callback: " + name);
    }
});

["init", "preflight", "status", "list", "addUrl", "remove", "move", "setOption", "applyTemporary", "enable", "disable", "reset", "getInstalledAppInfo", "fetchUpdateManifest", "installUpdate", "testScreensaver"].forEach(function(name) {
    if (webos.indexOf("WebOSService.prototype." + name) === -1) {
        throw new Error("missing WebOS adapter method: " + name);
    }
});

["btn-update-check", "btn-update-install", "btn-update-auto", "value-update-version", "update-detail"].forEach(function(id) {
    if (!ids[id]) {
        throw new Error("missing update UI id: " + id);
    }
});

if (html.indexOf('<script src="js/update.js"></script>') === -1) {
    throw new Error("update policy script is not loaded");
}
if (updater.indexOf("UpdatePolicy.validateManifest") === -1 || updater.indexOf("new UpdateController") === -1) {
    throw new Error("in-app updater controller is incomplete");
}
if (updater.indexOf("window.confirm") !== -1) {
    throw new Error("updater still relies on the unreliable native confirmation dialog");
}
["autoConfirmArmed", "installConfirmArmed", "Press again to enable", "Press again to install"].forEach(function(token) {
    if (updater.indexOf(token) === -1) {
        throw new Error("missing in-app updater confirmation token: " + token);
    }
});

console.log("UI contract test passed");
