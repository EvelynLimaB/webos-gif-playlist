APP_ID   = com.evelyn.webosgifplaylist
VERSION  = $(shell node -p "require('./appinfo.json').version")
IPK      = $(APP_ID)_$(VERSION)_all.ipk
DEVICE   = tv

.PHONY: all package install apply launch update clean test status disable reset inspect

all: package

package:
	@echo "Packaging $(APP_ID) v$(VERSION)..."
	@ares-package . \
		-e ".git" \
		-e ".env" \
		-e "*.ipk" \
		-e "Makefile" \
		-e "AGENTS.md" \
		-e "store-description.md" \
		-e "*.manifest.json" \
		-e "test" \
		-e "default.gif" \
		-e "default1.gif" \
		-e "default2.gif" \
		-e "default3.gif" \
		-e "default4.gif" \
		-e "default_download.gif"
	@echo "Built: $(IPK)"

install: package
	@ares-install -d $(DEVICE) $(IPK)

apply:
	@ares-shell -d $(DEVICE) -r "sh /media/developer/apps/usr/palm/applications/$(APP_ID)/assets/install.sh"

launch:
	@ares-launch -d $(DEVICE) $(APP_ID)

update: install apply launch

status:
	@ares-shell -d $(DEVICE) -r "sh /media/developer/apps/usr/palm/applications/$(APP_ID)/assets/manager.sh status"

disable:
	@ares-shell -d $(DEVICE) -r "sh /media/developer/apps/usr/palm/applications/$(APP_ID)/assets/manager.sh disable"

reset:
	@ares-shell -d $(DEVICE) -r "sh /media/developer/apps/usr/palm/applications/$(APP_ID)/assets/manager.sh reset"

test:
	@ares-launch -d $(DEVICE) com.webos.app.home
	@sleep 3
	@ares-shell -d $(DEVICE) -r "luna-send -n 1 luna://com.webos.service.tvpower/power/turnOnScreenSaver '{}'"

clean:
	@rm -f *.ipk *.manifest.json

inspect:
	@ares-inspect -d $(DEVICE) -o $(APP_ID)
