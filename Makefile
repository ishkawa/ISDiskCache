test:
	xcodebuild \
		-sdk iphonesimulator \
		-target ISDiskCacheTests \
		-configuration Debug \
		clean build \
		ONLY_ACTIVE_ARCH=NO \
		TEST_AFTER_BUILD=YES

