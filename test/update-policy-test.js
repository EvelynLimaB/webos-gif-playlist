"use strict";

var fs = require("fs");
var path = require("path");
var vm = require("vm");
var root = path.resolve(__dirname, "..");
var source = fs.readFileSync(path.join(root, "js/update.js"), "utf8");
var values = {};
var storage = {
    getItem: function(key) { return values[key] || null; },
    setItem: function(key, value) { values[key] = String(value); },
    removeItem: function(key) { delete values[key]; }
};
var context = {
    window: {
        localStorage: storage,
        addEventListener: function() {}
    },
    console: console,
    Promise: Promise,
    Error: Error,
    Array: Array,
    String: String,
    parseInt: parseInt
};
var policy;
var manifest;

vm.createContext(context);
vm.runInContext(source, context, {filename: "update.js"});
policy = context.UpdatePolicy;

if (!policy) {
    throw new Error("UpdatePolicy was not exported globally");
}
if (!policy.isNewer("0.2.4", "0.2.5")) {
    throw new Error("newer version was not detected");
}
if (policy.isNewer("0.2.5", "0.2.5")) {
    throw new Error("equal version was treated as newer");
}
if (policy.compareVersions("1.0.0", "0.9.9") <= 0) {
    throw new Error("version ordering is incorrect");
}
if (!policy.isMissingReleaseError("Update manifest request failed with HTTP 404.")) {
    throw new Error("GitHub latest-release 404 was not recognized");
}
if (!policy.isMissingReleaseError({message: "request status 404"})) {
    throw new Error("structured missing-release error was not recognized");
}
if (policy.isMissingReleaseError("Update manifest request failed with HTTP 500.")) {
    throw new Error("server failure was mistaken for an empty release channel");
}

manifest = {
    id: "com.evelyn.webosgifplaylist",
    version: "0.2.5",
    type: "web",
    title: "Screensaver Playlist",
    appDescription: "test",
    sourceUrl: "https://github.com/EvelynLimaB/webos-gif-playlist",
    ipkUrl: "https://github.com/EvelynLimaB/webos-gif-playlist/releases/download/v0.2.5/com.evelyn.webosgifplaylist_0.2.5_all.ipk",
    rootRequired: true,
    ipkHash: {
        sha256: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    }
};

if (policy.validateManifest(manifest).version !== "0.2.5") {
    throw new Error("valid manifest was rejected");
}

function expectRejected(changer, description) {
    var copy = JSON.parse(JSON.stringify(manifest));
    var rejected = false;
    changer(copy);
    try {
        policy.validateManifest(copy);
    } catch (error) {
        rejected = true;
    }
    if (!rejected) {
        throw new Error(description);
    }
}

expectRejected(function(value) { value.id = "other.app"; }, "foreign package id was accepted");
expectRejected(function(value) { value.sourceUrl = "https://example.com/repository"; }, "foreign source repository was accepted");
expectRejected(function(value) { value.ipkUrl = "https://example.com/update.ipk"; }, "foreign package URL was accepted");
expectRejected(function(value) { value.ipkHash.sha256 = "bad"; }, "invalid package hash was accepted");
expectRejected(function(value) { value.version = "0.2.5-beta"; }, "unsupported version format was accepted");

policy.setAutomaticUpdates(storage, true);
if (!policy.automaticUpdatesEnabled(storage)) {
    throw new Error("automatic update preference was not persisted");
}
policy.setPendingVersion(storage, "0.2.5");
if (policy.pendingVersion(storage) !== "0.2.5") {
    throw new Error("pending update version was not persisted");
}
policy.setPendingVersion(storage, "");
if (policy.pendingVersion(storage) !== "") {
    throw new Error("pending update version was not cleared");
}

console.log("update policy test passed");
