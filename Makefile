APP_ID   = com.evelyn.webosgifplaylist
VERSION  = $(shell node -p "require('./appinfo.json').version")
IPK      = $(APP_ID)_$(VERSION)_all.ipk
DEVICE   = tv
DIST     = dist

.PHONY: all stage package install apply enable launch update clean test status preflight disable reset inspect

all: package

stage:
	@rm -rf $(DIST)
	@mkdir -p $(DIST)/assets $(DIST)/css $(DIST)/js
	@cp appinfo.json index.html LICENSE $(DIST)/
	@cp css/app.css $(DIST)/css/
	@cp js/webos.js js/view.js js/app.js $(DIST)/js/
	@cp assets/idlegif80.png assets/idlegif130.png assets/idlegif300.png $(DIST)/assets/
	@cp assets/manager.sh assets/install.sh assets/uninstall.sh $(DIST)/assets/

package: stage
	@echo "Packaging $(APP_ID) v$(VERSION)..."
	@ares-package $(DIST)/
	@echo "Built: $(IPK)"

install: package
	@ares-install -d $(DEVICE) $(IPK)

apply:
	@ares-shell -d $(DEVICE) -r "sh /media/developer/apps/usr/palm/applications/$(APP_ID)/assets/manager.sh apply"

enable:
	@ares-shell -d $(DEVICE) -r "sh /media/developer/apps/usr/palm/applications/$(APP_ID)/assets/manager.sh enable"

launch:
	@ares-launch -d $(DEVICE) $(APP_ID)

update: install launch

status:
	@ares-shell -d $(DEVICE) -r "sh /media/developer/apps/usr/palm/applications/$(APP_ID)/assets/manager.sh status"

preflight:
	@ares-shell -d $(DEVICE) -r "sh /media/developer/apps/usr/palm/applications/$(APP_ID)/assets/manager.sh preflight"

disable:
	@ares-shell -d $(DEVICE) -r "sh /media/developer/apps/usr/palm/applications/$(APP_ID)/assets/manager.sh disable"

reset:
	@ares-shell -d $(DEVICE) -r "sh /media/developer/apps/usr/palm/applications/$(APP_ID)/assets/manager.sh reset"

test:
	@ares-shell -d $(DEVICE) -r "sh /media/developer/apps/usr/palm/applications/$(APP_ID)/assets/manager.sh apply"
	@ares-launch -d $(DEVICE) com.webos.app.home
	@sleep 3
	@ares-shell -d $(DEVICE) -r "luna-send -n 1 luna://com.webos.service.tvpower/power/turnOnScreenSaver '{}'"

clean:
	@rm -rf $(DIST)
	@rm -f *.ipk *.manifest.json

inspect:
	@ares-inspect -d $(DEVICE) -o $(APP_ID)
