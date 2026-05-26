ZIP_NAME ?= cooked.zip

ZIP_SOURCES := \
	README.md \
	Cooked \
	Cooked.xcodeproj \
	CookedWidget

.PHONY: zip clean

zip:
	@rm -f "$(ZIP_NAME)"
	@cd Cooked_app && zip -rq "../$(ZIP_NAME)" $(ZIP_SOURCES) \
		-x "*/.DS_Store" \
		-x "*/xcuserdata/*" \
		-x "*/xcshareddata/swiftpm/*" \
		-x "*/project.xcworkspace/xcuserdata/*"

clean:
	@rm -f "$(ZIP_NAME)"