function App() {
    this.webos = new WebOSService();
    this.view = new View();
    this.state = {
        enabled: "no",
        autostart: "no",
        target: "",
        count: "0",
        bytes: "0",
        mode: "ordered",
        duration: "30000",
        fit: "crop",
        filter: "smooth",
        maxItems: "24"
    };
    this.items = [];
    this.resetConfirmArmed = false;
    this.resetConfirmTimer = null;
    this._wireCallbacks();
}

App.prototype._wireCallbacks = function() {
    var self = this;

    this.view.onAdd(function(url) {
        self._run("Downloading and validating image…", function() {
            return self.webos.addUrl(url);
        }, true);
    });

    this.view.onRemove(function(id) {
        self._run("Removing image…", function() {
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
        var modes = ["crop", "fit", "stretch"];
        var index = modes.indexOf(self.state.fit);
        var next = modes[(index + 1) % modes.length];
        self._run("Updating image scaling…", function() {
            return self.webos.setOption("fit", next);
        }, true);
    });

    this.view.onFilter(function() {
        var next = self.state.filter === "pixel" ? "smooth" : "pixel";
        self._run("Updating scaling filter…", function() {
            return self.webos.setOption("filter", next);
        }, true);
    });

    this.view.onDuration(function() {
        var durations = [10000, 20000, 30000, 60000, 120000, 300000];
        var current = parseInt(self.state.duration, 10);
        var index = durations.indexOf(current);
        var next = durations[(index + 1) % durations.length];
        self._run("Updating rotation interval…", function() {
            return self.webos.setOption("duration", String(next));
        }, true);
    });

    this.view.onRefresh(function() {
        self._clearResetConfirmation();
        self.refresh();
    });

    this.view.onCheck(function() {
        self._run("Checking TV compatibility…", function() {
            return self.webos.preflight();
        }, false);
    });

    this.view.onApply(function() {
        self._run("Applying until the next reboot…", function() {
            return self.webos.applyTemporary();
        }, true);
    });

    this.view.onEnable(function() {
        self._run("Applying screensaver and enabling boot startup…", function() {
            return self.webos.enable();
        }, true);
    });

    this.view.onDisable(function() {
        self._run("Restoring the stock screensaver…", function() {
            return self.webos.disable();
        }, true);
    });

    this.view.onTest(function() {
        self._clearResetConfirmation();
        self.view.setBusy(true);
        self.view.setStatus("Applying temporarily and opening the screensaver…");
        self.webos.testScreensaver().then(function(output) {
            self.view.setStatus(String(output || "Screensaver trigger sent.").trim(), "ok");
            return self.refresh(true);
        }).catch(function(error) {
            self.view.setBusy(false);
            self.view.setStatus("Test failed: " + self._errorText(error), "err");
        });
    });

    this.view.onReset(function() {
        if (!self.resetConfirmArmed) {
            self._armResetConfirmation();
            return;
        }

        self._clearResetConfirmation();
        self._run("Resetting playlist data…", function() {
            return self.webos.reset();
        }, true);
    });
};

App.prototype._clearResetConfirmation = function() {
    var button = document.getElementById("btn-reset");

    if (this.resetConfirmTimer) {
        clearTimeout(this.resetConfirmTimer);
        this.resetConfirmTimer = null;
    }
    this.resetConfirmArmed = false;
    if (button) {
        button.textContent = "Reset all data";
        button.className = "danger";
    }
};

App.prototype._armResetConfirmation = function() {
    var self = this;
    var button = document.getElementById("btn-reset");

    this._clearResetConfirmation();
    this.resetConfirmArmed = true;
    if (button) {
        button.textContent = "Press again to reset";
        button.className = "danger";
    }
    this.view.setStatus(
        "Press Reset all data again within 15 seconds to delete every local image and setting.",
        "err"
    );
    this.resetConfirmTimer = setTimeout(function() {
        self.resetConfirmTimer = null;
        self.resetConfirmArmed = false;
        if (button) {
            button.textContent = "Reset all data";
            button.className = "danger";
        }
        self.view.setStatus("Reset cancelled. No data was removed.", "ok");
    }, 15000);
};

App.prototype._errorText = function(error) {
    if (error === null || typeof error === "undefined") {
        return "Unknown error";
    }
    if (typeof error === "string") {
        return error;
    }
    if (error.message) {
        return error.message;
    }
    try {
        return JSON.stringify(error);
    } catch (ignored) {
        return String(error);
    }
};

App.prototype._parseStatus = function(text) {
    var result = {};
    var lines = String(text || "").split(/\r?\n/);
    var index;

    for (index = 0; index < lines.length; index += 1) {
        var separator = lines[index].indexOf("=");
        if (separator > 0) {
            result[lines[index].slice(0, separator)] = lines[index].slice(separator + 1);
        }
    }
    return result;
};

App.prototype._parseItems = function(text) {
    var items = [];
    var lines = String(text || "").split(/\r?\n/);
    var index;

    for (index = 0; index < lines.length; index += 1) {
        if (lines[index]) {
            var fields = lines[index].split("\t");
            if (fields[0]) {
                items.push({
                    id: fields[0],
                    bytes: parseInt(fields[1] || "0", 10) || 0,
                    format: fields[2] || "unknown",
                    dimensions: fields[3] || "unknown"
                });
            }
        }
    }
    return items;
};

App.prototype._run = function(message, operation, refreshAfter) {
    var self = this;
    var promise;

    this._clearResetConfirmation();
    this.view.setBusy(true);
    this.view.setStatus(message);

    try {
        promise = operation();
    } catch (error) {
        this.view.setBusy(false);
        this.view.setStatus(this._errorText(error), "err");
        return;
    }

    promise.then(function(output) {
        self.view.setStatus(String(output || "Done.").trim(), "ok");
        if (refreshAfter) {
            return self.refresh(true);
        }
        self.view.setBusy(false);
        return null;
    }).catch(function(error) {
        self.view.setBusy(false);
        self.view.setStatus(self._errorText(error), "err");
    });
};

App.prototype.refresh = function(keepStatus) {
    var self = this;
    this.view.setBusy(true);
    if (!keepStatus) {
        this.view.setStatus("Reading TV state…");
    }

    return Promise.all([
        this.webos.status(),
        this.webos.list()
    ]).then(function(results) {
        var parsed = self._parseStatus(results[0]);
        var key;
        for (key in parsed) {
            if (parsed.hasOwnProperty(key)) {
                self.state[key] = parsed[key];
            }
        }
        self.items = self._parseItems(results[1]);
        self.view.setBusy(false);
        self.view.render(self.state, self.items);
        if (!keepStatus) {
            self.view.setStatus("Ready.", "ok");
        }
    }).catch(function(error) {
        self.view.setBusy(false);
        self.view.setStatus(self._errorText(error), "err");
    });
};

App.prototype.init = function() {
    var self = this;
    this.view.setBusy(true);
    this.view.setStatus("Initializing local playlist storage…");
    this.webos.init().then(function() {
        return self.refresh(false);
    }).catch(function(error) {
        self.view.setBusy(false);
        self.view.setStatus(self._errorText(error), "err");
    });
};

window.addEventListener("DOMContentLoaded", function() {
    new App().init();
});
