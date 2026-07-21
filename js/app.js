// GIF Playlist application controller.
// Avoids Promise.finally and newer JavaScript syntax for webOS 4.x.

function App() {
    this.webos = new WebOSService();
    this.view = new View();
    this.state = {
        enabled: "no",
        target: "",
        count: "0",
        mode: "ordered",
        duration: "30000",
        fit: "crop"
    };
    this.items = [];
    this._wireCallbacks();
}

App.prototype._wireCallbacks = function() {
    var self = this;

    this.view.onAdd(function(url) {
        self._run("Downloading and validating GIF…", function() {
            return self.webos.addUrl(url);
        }, true);
    });

    this.view.onRemove(function(id) {
        self._run("Removing GIF…", function() {
            return self.webos.remove(id);
        }, true);
    });

    this.view.onMove(function(id, direction) {
        self._run("Reordering playlist…", function() {
            return self.webos.move(id, direction);
        }, true);
    });

    this.view.onMode(function() {
        var next = self.state.mode === "shuffle" ? "ordered" : "shuffle";
        self._run("Updating playback mode…", function() {
            return self.webos.setOption("mode", next);
        }, true);
    });

    this.view.onFit(function() {
        var order = ["crop", "fit", "stretch"];
        var index = order.indexOf(self.state.fit);
        var next = order[(index + 1) % order.length];
        self._run("Updating image scaling…", function() {
            return self.webos.setOption("fit", next);
        }, true);
    });

    this.view.onDuration(function() {
        var durations = [10000, 20000, 30000, 60000, 120000];
        var current = parseInt(self.state.duration, 10);
        var index = durations.indexOf(current);
        var next = durations[(index + 1) % durations.length];
        self._run("Updating rotation interval…", function() {
            return self.webos.setOption("duration", String(next));
        }, true);
    });

    this.view.onRefresh(function() {
        self.refresh();
    });

    this.view.onEnable(function() {
        self._run("Applying screensaver override…", function() {
            return self.webos.enable();
        }, true);
    });

    this.view.onDisable(function() {
        self._run("Restoring the stock screensaver…", function() {
            return self.webos.disable();
        }, true);
    });

    this.view.onTest(function() {
        self.view.setStatus("Opening the screensaver…");
        self.webos.testScreensaver()
            .then(function() {
                self.view.setStatus("Screensaver trigger sent.", "ok");
            })
            .catch(function(error) {
                self.view.setStatus("Test failed: " + self._errorText(error), "err");
            });
    });

    this.view.onReset(function() {
        if (window.confirm && !window.confirm("Remove every downloaded GIF and restore the stock screensaver?")) {
            return;
        }
        self._run("Resetting playlist data…", function() {
            return self.webos.reset();
        }, true);
    });
};

App.prototype._errorText = function(error) {
    if (error === null || typeof error === "undefined") return "Unknown error";
    if (typeof error === "string") return error;
    if (error.message) return error.message;
    try { return JSON.stringify(error); } catch (ignored) { return String(error); }
};

App.prototype._parseStatus = function(text) {
    var result = {};
    var lines = String(text || "").split(/\r?\n/);
    var i;
    for (i = 0; i < lines.length; i++) {
        var equals = lines[i].indexOf("=");
        if (equals <= 0) continue;
        result[lines[i].slice(0, equals)] = lines[i].slice(equals + 1);
    }
    return result;
};

App.prototype._parseItems = function(text) {
    var items = [];
    var lines = String(text || "").split(/\r?\n/);
    var i;
    for (i = 0; i < lines.length; i++) {
        if (!lines[i]) continue;
        var columns = lines[i].split("\t");
        if (!columns[0]) continue;
        items.push({
            id: columns[0],
            bytes: parseInt(columns[1] || "0", 10) || 0
        });
    }
    return items;
};

App.prototype._run = function(message, operation, refreshAfter) {
    var self = this;
    this.view.setBusy(true);
    this.view.setStatus(message);

    operation()
        .then(function(output) {
            self.view.setStatus(String(output || "Done.").trim(), "ok");
            if (refreshAfter) return self.refresh(true);
            self.view.setBusy(false);
            return null;
        })
        .catch(function(error) {
            self.view.setBusy(false);
            self.view.setStatus(self._errorText(error), "err");
        });
};

App.prototype.refresh = function(keepMessage) {
    var self = this;
    this.view.setBusy(true);
    if (!keepMessage) this.view.setStatus("Reading TV state…");

    return Promise.all([this.webos.status(), this.webos.list()])
        .then(function(results) {
            var parsed = self._parseStatus(results[0]);
            var key;
            for (key in parsed) {
                if (parsed.hasOwnProperty(key)) self.state[key] = parsed[key];
            }
            self.items = self._parseItems(results[1]);
            self.view.render(self.state, self.items);
            self.view.setBusy(false);
            if (!keepMessage) self.view.setStatus("Ready.", "ok");
        })
        .catch(function(error) {
            self.view.setBusy(false);
            self.view.setStatus(self._errorText(error), "err");
        });
};

App.prototype.init = function() {
    var self = this;
    this.view.setBusy(true);
    this.view.setStatus("Initializing playlist storage…");
    this.webos.init()
        .then(function() {
            return self.refresh(false);
        })
        .catch(function(error) {
            self.view.setBusy(false);
            self.view.setStatus(self._errorText(error), "err");
        });
};

window.addEventListener("DOMContentLoaded", function() {
    new App().init();
});
