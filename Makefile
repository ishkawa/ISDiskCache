test:
	xcodebuild \
		-sdk iphonesimulator \
		-target ISDiskCacheTests \
		-configuration Debug \
		clean build \
		TEST_AFTER_BUILD=YES \
		GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES \
		GCC_GENERATE_TEST_COVERAGE_FILES=YES

coveralls:
	coveralls -e ISDiskCacheTests

