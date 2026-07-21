APP_ID   := com.evelyn.webosgifplaylist
VERSION  := $(shell node -p "require('./appinfo.json').version")
IPK      := $(APP_ID)_$(VERSION)_all.ipk
DEVICE   ?= tv
DIST     := dist
APP_PATH := /media/developer/apps/usr/palm/applications/$(APP_ID)

.PHONY: all check check-js shellcheck test stage package audit-package install update launch \
        status preflight apply enable test-tv disable reset inspect clean

all: check package

check: shellcheck test check-js

check-js:
	@node --check js/webos.js
	@node --check js/view.js
	@node --check js/app.js
	@! grep -RE '=>|\.finally[[:space:]]*\(|\basync\b|\bawait\b|\bclass[[:space:]]' js/webos.js js/view.js js/app.js
	@! grep -RE '(^|[;{[:space:]])gap[[:space:]]*:|display:[[:space:]]*grid|var\(--' css/app.css

shellcheck:
	@sh -n assets/manager.sh assets/install.sh assets/uninstall.sh assets/lib/*.sh tools/send-media.sh test/*.sh
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck assets/*.sh assets/lib/*.sh tools/*.sh test/*.sh; \
	else \
		echo "shellcheck not installed; syntax checks only"; \
	fi

test:
	@sh test/manager-test.sh
	@sh test/batch-import-test.sh
	@sh test/send-media-test.sh
	@node test/ui-contract-test.js

stage:
	@rm -rf $(DIST)
	@mkdir -p $(DIST)/assets/lib $(DIST)/css $(DIST)/js
	@cp appinfo.json index.html LICENSE $(DIST)/
	@cp css/app.css $(DIST)/css/
	@cp js/webos.js js/view.js js/app.js $(DIST)/js/
	@cp assets/idlegif80.png assets/idlegif130.png assets/idlegif300.png $(DIST)/assets/
	@cp assets/manager.sh assets/install.sh assets/uninstall.sh $(DIST)/assets/
	@cp assets/lib/core.sh assets/lib/media.sh assets/lib/batch.sh assets/lib/commands.sh $(DIST)/assets/lib/

package: stage
	@command -v ares-package >/dev/null 2>&1 || { \
		echo "ares-package is missing. Install @webos-tools/cli." >&2; exit 1; \
	}
	@echo "Packaging $(APP_ID) v$(VERSION)..."
	@ares-package $(DIST)/
	@test -f $(IPK)
	@echo "Built: $(IPK)"

audit-package:
	@test -f $(IPK) || { echo "Build $(IPK) first." >&2; exit 1; }
	@rm -rf package-audit
	@mkdir -p package-audit
	@cd package-audit && ar x ../$(IPK) && tar -xzf data.tar.gz
	@sh test/package-test.sh package-audit/usr/palm/applications/$(APP_ID)

install: package
	@ares-install -d $(DEVICE) $(IPK)

update: install launch

launch:
	@ares-launch -d $(DEVICE) $(APP_ID)

status:
	@ares-shell -d $(DEVICE) -r "sh $(APP_PATH)/assets/manager.sh status"

preflight:
	@ares-shell -d $(DEVICE) -r "sh $(APP_PATH)/assets/manager.sh preflight"

apply:
	@ares-shell -d $(DEVICE) -r "sh $(APP_PATH)/assets/manager.sh apply"

enable:
	@ares-shell -d $(DEVICE) -r "sh $(APP_PATH)/assets/manager.sh enable"

test-tv:
	@ares-shell -d $(DEVICE) -r "sh $(APP_PATH)/assets/manager.sh apply"
	@ares-launch -d $(DEVICE) com.webos.app.home
	@sleep 3
	@ares-shell -d $(DEVICE) -r "luna-send -n 1 luna://com.webos.service.tvpower/power/turnOnScreenSaver '{}'"

disable:
	@ares-shell -d $(DEVICE) -r "sh $(APP_PATH)/assets/manager.sh disable"

reset:
	@ares-shell -d $(DEVICE) -r "sh $(APP_PATH)/assets/manager.sh reset"

inspect:
	@ares-inspect -d $(DEVICE) -o $(APP_ID)

clean:
	@rm -rf $(DIST) package-audit
	@rm -f *.ipk *.manifest.json
