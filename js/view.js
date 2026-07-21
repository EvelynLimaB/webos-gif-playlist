// DOM view and remote-control navigation for Chromium 53-era webOS.

function View() {
    this._callbacks = {};
    this._focusables = [];
    this._focusIndex = 0;
    this._busy = false;
    this._bindStaticControls();
    this._bindNavigation();
}

View.prototype.onAdd = function(callback) { this._callbacks.add = callback; };
View.prototype.onRemove = function(callback) { this._callbacks.remove = callback; };
View.prototype.onMove = function(callback) { this._callbacks.move = callback; };
View.prototype.onMode = function(callback) { this._callbacks.mode = callback; };
View.prototype.onFit = function(callback) { this._callbacks.fit = callback; };
View.prototype.onDuration = function(callback) { this._callbacks.duration = callback; };
View.prototype.onRefresh = function(callback) { this._callbacks.refresh = callback; };
View.prototype.onEnable = function(callback) { this._callbacks.enable = callback; };
View.prototype.onDisable = function(callback) { this._callbacks.disable = callback; };
View.prototype.onTest = function(callback) { this._callbacks.test = callback; };
View.prototype.onReset = function(callback) { this._callbacks.reset = callback; };

View.prototype._bindStaticControls = function() {
    var self = this;

    document.getElementById("btn-add").onclick = function() {
        var value = document.getElementById("url-input").value.replace(/^\s+|\s+$/g, "");
        if (self._callbacks.add) self._callbacks.add(value);
    };
    document.getElementById("btn-mode").onclick = function() {
        if (self._callbacks.mode) self._callbacks.mode();
    };
    document.getElementById("btn-fit").onclick = function() {
        if (self._callbacks.fit) self._callbacks.fit();
    };
    document.getElementById("btn-duration").onclick = function() {
        if (self._callbacks.duration) self._callbacks.duration();
    };
    document.getElementById("btn-refresh").onclick = function() {
        if (self._callbacks.refresh) self._callbacks.refresh();
    };
    document.getElementById("btn-enable").onclick = function() {
        if (self._callbacks.enable) self._callbacks.enable();
    };
    document.getElementById("btn-disable").onclick = function() {
        if (self._callbacks.disable) self._callbacks.disable();
    };
    document.getElementById("btn-test").onclick = function() {
        if (self._callbacks.test) self._callbacks.test();
    };
    document.getElementById("btn-reset").onclick = function() {
        if (self._callbacks.reset) self._callbacks.reset();
    };
};

View.prototype._formatBytes = function(bytes) {
    if (bytes < 1024) return bytes + " B";
    if (bytes < 1048576) return (bytes / 1024).toFixed(1) + " KiB";
    return (bytes / 1048576).toFixed(1) + " MiB";
};

View.prototype.render = function(state, items) {
    document.getElementById("value-enabled").textContent = state.enabled === "yes" ? "Enabled" : "Disabled";
    document.getElementById("value-target").textContent = state.target || "Not detected";
    document.getElementById("value-count").textContent = String(items.length) + " / 12";
    document.getElementById("btn-mode").textContent = "Order: " + (state.mode === "shuffle" ? "Shuffle" : "Sequential");

    var fitLabels = { crop: "Crop", fit: "Fit", stretch: "Stretch" };
    document.getElementById("btn-fit").textContent = "Scaling: " + (fitLabels[state.fit] || "Crop");
    document.getElementById("btn-duration").textContent = "Switch every: " + Math.round((parseInt(state.duration, 10) || 30000) / 1000) + "s";

    var indicator = document.getElementById("enabled-indicator");
    indicator.className = state.enabled === "yes" ? "indicator enabled" : "indicator disabled";

    var container = document.getElementById("playlist");
    while (container.firstChild) container.removeChild(container.firstChild);

    if (!items.length) {
        var empty = document.createElement("div");
        empty.className = "empty";
        empty.textContent = "No GIFs downloaded yet.";
        container.appendChild(empty);
    }

    var self = this;
    var i;
    for (i = 0; i < items.length; i++) {
        (function(item, index) {
            var row = document.createElement("div");
            row.className = "playlist-row";

            var position = document.createElement("div");
            position.className = "position";
            position.textContent = String(index + 1);

            var details = document.createElement("div");
            details.className = "details";

            var name = document.createElement("div");
            name.className = "item-name";
            name.textContent = item.id;

            var size = document.createElement("div");
            size.className = "item-size";
            size.textContent = self._formatBytes(item.bytes);

            details.appendChild(name);
            details.appendChild(size);

            var controls = document.createElement("div");
            controls.className = "row-controls";

            var up = document.createElement("button");
            up.textContent = "Up";
            up.disabled = index === 0;
            up.onclick = function() {
                if (self._callbacks.move) self._callbacks.move(item.id, "up");
            };

            var down = document.createElement("button");
            down.textContent = "Down";
            down.disabled = index === items.length - 1;
            down.onclick = function() {
                if (self._callbacks.move) self._callbacks.move(item.id, "down");
            };

            var remove = document.createElement("button");
            remove.className = "danger compact";
            remove.textContent = "Remove";
            remove.onclick = function() {
                if (self._callbacks.remove) self._callbacks.remove(item.id);
            };

            controls.appendChild(up);
            controls.appendChild(down);
            controls.appendChild(remove);
            row.appendChild(position);
            row.appendChild(details);
            row.appendChild(controls);
            container.appendChild(row);
        })(items[i], i);
    }

    this._rebuildFocusables();
    this.setBusy(this._busy);
};

View.prototype.setStatus = function(message, type) {
    var status = document.getElementById("status");
    status.textContent = message || "";
    status.className = type || "";
};

View.prototype.setBusy = function(busy) {
    this._busy = !!busy;
    var buttons = document.getElementsByTagName("button");
    var i;
    for (i = 0; i < buttons.length; i++) {
        if (buttons[i].getAttribute("data-permanent-disabled") === "true") continue;
        if (busy) {
            buttons[i].setAttribute("data-was-disabled", buttons[i].disabled ? "true" : "false");
            buttons[i].disabled = true;
        } else {
            var wasDisabled = buttons[i].getAttribute("data-was-disabled");
            if (wasDisabled !== null) {
                buttons[i].disabled = wasDisabled === "true";
                buttons[i].removeAttribute("data-was-disabled");
            }
        }
    }
    document.getElementById("app").className = busy ? "busy" : "";
    if (!busy) this._rebuildFocusables();
};

View.prototype._rebuildFocusables = function() {
    var previous = this._focusables[this._focusIndex];
    var nodes = document.querySelectorAll("button:not([disabled]), input:not([disabled])");
    this._focusables = [];
    var i;
    for (i = 0; i < nodes.length; i++) this._focusables.push(nodes[i]);

    var nextIndex = previous ? this._focusables.indexOf(previous) : -1;
    this._focusIndex = nextIndex >= 0 ? nextIndex : 0;
    if (this._focusables[this._focusIndex]) this._focusables[this._focusIndex].focus();
};

View.prototype._bindNavigation = function() {
    var self = this;
    document.addEventListener("keydown", function(event) {
        var key = event.keyCode;
        if (key !== 37 && key !== 38 && key !== 39 && key !== 40 && key !== 13) return;

        var active = document.activeElement;
        if (active && active.tagName === "INPUT" && (key === 37 || key === 39 || key === 13)) {
            if (key === 13) {
                event.preventDefault();
                document.getElementById("btn-add").click();
            }
            return;
        }

        if (!self._focusables.length) return;
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
        self._focusables[self._focusIndex].focus();
    });
};
