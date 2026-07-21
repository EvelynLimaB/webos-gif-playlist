function View() {
    this._callbacks = {};
    this._focusables = [];
    this._focusIndex = 0;
    this._busy = false;
    this._bindStaticControls();
    this._bindNavigation();
}

View.prototype._bindStaticControls = function() {
    var self = this;

    document.getElementById("btn-add").addEventListener("click", function() {
        var input = document.getElementById("url-input");
        if (self._callbacks.add) {
            self._callbacks.add(input.value.trim());
        }
    });
    document.getElementById("btn-mode").addEventListener("click", function() {
        if (self._callbacks.mode) { self._callbacks.mode(); }
    });
    document.getElementById("btn-fit").addEventListener("click", function() {
        if (self._callbacks.fit) { self._callbacks.fit(); }
    });
    document.getElementById("btn-filter").addEventListener("click", function() {
        if (self._callbacks.filter) { self._callbacks.filter(); }
    });
    document.getElementById("btn-duration").addEventListener("click", function() {
        if (self._callbacks.duration) { self._callbacks.duration(); }
    });
    document.getElementById("btn-refresh").addEventListener("click", function() {
        if (self._callbacks.refresh) { self._callbacks.refresh(); }
    });
    document.getElementById("btn-check").addEventListener("click", function() {
        if (self._callbacks.check) { self._callbacks.check(); }
    });
    document.getElementById("btn-apply").addEventListener("click", function() {
        if (self._callbacks.apply) { self._callbacks.apply(); }
    });
    document.getElementById("btn-enable").addEventListener("click", function() {
        if (self._callbacks.enable) { self._callbacks.enable(); }
    });
    document.getElementById("btn-test").addEventListener("click", function() {
        if (self._callbacks.test) { self._callbacks.test(); }
    });
    document.getElementById("btn-disable").addEventListener("click", function() {
        if (self._callbacks.disable) { self._callbacks.disable(); }
    });
    document.getElementById("btn-reset").addEventListener("click", function() {
        if (self._callbacks.reset) { self._callbacks.reset(); }
    });
};

View.prototype.onAdd = function(callback) { this._callbacks.add = callback; };
View.prototype.onRemove = function(callback) { this._callbacks.remove = callback; };
View.prototype.onMove = function(callback) { this._callbacks.move = callback; };
View.prototype.onMode = function(callback) { this._callbacks.mode = callback; };
View.prototype.onFit = function(callback) { this._callbacks.fit = callback; };
View.prototype.onFilter = function(callback) { this._callbacks.filter = callback; };
View.prototype.onDuration = function(callback) { this._callbacks.duration = callback; };
View.prototype.onRefresh = function(callback) { this._callbacks.refresh = callback; };
View.prototype.onCheck = function(callback) { this._callbacks.check = callback; };
View.prototype.onApply = function(callback) { this._callbacks.apply = callback; };
View.prototype.onEnable = function(callback) { this._callbacks.enable = callback; };
View.prototype.onTest = function(callback) { this._callbacks.test = callback; };
View.prototype.onDisable = function(callback) { this._callbacks.disable = callback; };
View.prototype.onReset = function(callback) { this._callbacks.reset = callback; };

View.prototype._humanBytes = function(bytes) {
    if (bytes >= 1048576) {
        return (bytes / 1048576).toFixed(1) + " MiB";
    }
    if (bytes >= 1024) {
        return Math.round(bytes / 1024) + " KiB";
    }
    return bytes + " B";
};

View.prototype._formatName = function(format) {
    return ({
        gif: "GIF",
        png: "PNG/APNG",
        jpg: "JPEG",
        webp: "WebP"
    })[format] || String(format || "Unknown").toUpperCase();
};

View.prototype.render = function(state, items) {
    var indicator = document.getElementById("enabled-indicator");
    var enabledText = document.getElementById("value-enabled");
    var enabled = state.enabled === "yes";
    var autostart = state.autostart === "yes";
    var maxItems = parseInt(state.maxItems || "24", 10) || 24;

    indicator.className = enabled ? "indicator enabled" : "indicator disabled";
    if (enabled && autostart) {
        enabledText.textContent = "Enabled at boot";
    } else if (enabled) {
        enabledText.textContent = "Temporary";
    } else {
        enabledText.textContent = "Disabled";
    }

    document.getElementById("value-target").textContent = state.target || "Not found";
    document.getElementById("value-count").textContent = items.length + " / " + maxItems + " · " + this._humanBytes(parseInt(state.bytes || "0", 10) || 0);
    document.getElementById("btn-mode").textContent = state.mode === "shuffle" ? "Order: Shuffle" : "Order: Sequential";
    document.getElementById("btn-fit").textContent = "Scaling: " + ({crop: "Crop", fit: "Fit", stretch: "Stretch"}[state.fit] || "Crop");
    document.getElementById("btn-filter").textContent = state.filter === "pixel" ? "Filtering: Pixel" : "Filtering: Smooth";
    document.getElementById("btn-duration").textContent = "Switch every: " + Math.round((parseInt(state.duration, 10) || 30000) / 1000) + "s";
    document.getElementById("btn-add").disabled = items.length >= maxItems;

    this._renderPlaylist(items);
    this._rebuildFocusables();
};

View.prototype._renderPlaylist = function(items) {
    var container = document.getElementById("playlist");
    var self = this;
    var index;

    while (container.firstChild) {
        container.removeChild(container.firstChild);
    }

    if (!items.length) {
        var empty = document.createElement("div");
        empty.className = "empty";
        empty.textContent = "No images downloaded yet.";
        container.appendChild(empty);
        return;
    }

    for (index = 0; index < items.length; index += 1) {
        (function(item, position) {
            var row = document.createElement("div");
            row.className = "playlist-row";

            var number = document.createElement("div");
            number.className = "position";
            number.textContent = String(position + 1);

            var details = document.createElement("div");
            details.className = "details";
            var name = document.createElement("div");
            name.className = "item-name";
            name.textContent = item.id;
            var size = document.createElement("div");
            size.className = "item-size";
            size.textContent = self._formatName(item.format) + " · " + item.dimensions + " · " + self._humanBytes(item.bytes);
            details.appendChild(name);
            details.appendChild(size);

            var controls = document.createElement("div");
            controls.className = "row-controls";

            var up = document.createElement("button");
            up.className = "compact";
            up.textContent = "Up";
            up.disabled = position === 0;
            up.addEventListener("click", function() {
                if (self._callbacks.move) { self._callbacks.move(item.id, "up"); }
            });

            var down = document.createElement("button");
            down.className = "compact";
            down.textContent = "Down";
            down.disabled = position === items.length - 1;
            down.addEventListener("click", function() {
                if (self._callbacks.move) { self._callbacks.move(item.id, "down"); }
            });

            var remove = document.createElement("button");
            remove.className = "compact danger";
            remove.textContent = "Remove";
            remove.addEventListener("click", function() {
                if (self._callbacks.remove) { self._callbacks.remove(item.id); }
            });

            controls.appendChild(up);
            controls.appendChild(down);
            controls.appendChild(remove);
            row.appendChild(number);
            row.appendChild(details);
            row.appendChild(controls);
            container.appendChild(row);
        }(items[index], index));
    }
};

View.prototype.setStatus = function(message, type) {
    var status = document.getElementById("status");
    status.textContent = message || "";
    status.className = type || "";
};

View.prototype.setBusy = function(busy) {
    var buttons = document.getElementsByTagName("button");
    var index;
    this._busy = !!busy;

    for (index = 0; index < buttons.length; index += 1) {
        if (busy) {
            if (buttons[index].getAttribute("data-was-disabled") === null) {
                buttons[index].setAttribute("data-was-disabled", buttons[index].disabled ? "true" : "false");
            }
            buttons[index].disabled = true;
        } else {
            var previous = buttons[index].getAttribute("data-was-disabled");
            if (previous !== null) {
                buttons[index].disabled = previous === "true";
                buttons[index].removeAttribute("data-was-disabled");
            }
        }
    }

    document.getElementById("app").className = busy ? "busy" : "";
    if (!busy) {
        this._rebuildFocusables();
    }
};

View.prototype._rebuildFocusables = function() {
    var previous = this._focusables[this._focusIndex];
    var nodes = document.querySelectorAll("button:not([disabled]), input:not([disabled])");
    var index;

    this._focusables = [];
    for (index = 0; index < nodes.length; index += 1) {
        this._focusables.push(nodes[index]);
    }

    var previousIndex = previous ? this._focusables.indexOf(previous) : -1;
    this._focusIndex = previousIndex >= 0 ? previousIndex : 0;
    if (this._focusables[this._focusIndex]) {
        this._focusables[this._focusIndex].focus();
    }
};

View.prototype._focusCurrent = function() {
    var element = this._focusables[this._focusIndex];
    if (element) {
        element.focus();
        if (element.scrollIntoView) {
            element.scrollIntoView(false);
        }
    }
};

View.prototype._bindNavigation = function() {
    var self = this;
    document.addEventListener("keydown", function(event) {
        var key = event.keyCode;
        if (key !== 37 && key !== 38 && key !== 39 && key !== 40 && key !== 13) {
            return;
        }

        var active = document.activeElement;
        if (active && active.tagName === "INPUT") {
            if (key === 13) {
                event.preventDefault();
                document.getElementById("btn-add").click();
                return;
            }
            if (key === 37 || key === 39) {
                return;
            }
        }

        if (!self._focusables.length) {
            return;
        }

        event.preventDefault();
        if (key === 13) {
            self._focusables[self._focusIndex].click();
            return;
        }

        if (key === 37 || key === 38) {
            self._focusIndex = Math.max(0, self._focusIndex - 1);
        } else {
            self._focusIndex = Math.min(self._focusables.length - 1, self._focusIndex + 1);
        }
        self._focusCurrent();
    });
};
