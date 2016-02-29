CONFIGURATION?=Release
VERSION=$(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${PWD}/Kinvey/Kinvey/Info.plist")

all: build pack

build: build-ios

clean:
	rm -Rf docs
	rm -Rf build

build-debug:
	xcodebuild -workspace Kinvey.xcworkspace -scheme Kinvey -configuration Debug BUILD_DIR=build ONLY_ACTIVE_ARCH=NO -sdk iphoneos
	xcodebuild -workspace Kinvey.xcworkspace -scheme Kinvey -configuration Debug BUILD_DIR=build ONLY_ACTIVE_ARCH=NO -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 6S,OS=9.2'
	
build-ios:
	cd Kinvey; \
	carthage build --no-skip-current --platform ios

pack:
	mkdir -p build/Kinvey-$(VERSION)-Beta
	cd Kinvey/Carthage/Build/iOS; \
	cp -R Kinvey.framework PromiseKit.framework KeychainAccess.framework Realm.framework ../../../../build/Kinvey-$(VERSION)-Beta
	cd build; \
	zip -r Kinvey-$(VERSION)-Beta.zip Kinvey-$(VERSION)-Beta

docs:
	jazzy --author Kinvey \
				--author_url http://www.kinvey.com \
				--module-version $(VERSION) \
				--readme README-API-Reference-Docs.md \
				--podspec Kinvey.podspec \
				--min-acl public \
				--theme apple \
				--xcodebuild-arguments -workspace,Kinvey.xcworkspace,-scheme,Kinvey \
				--module Kinvey \
				--output docs

show-version:
	@/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${PWD}/Kinvey/Kinvey/Info.plist" | xargs echo 'Info.plist    '
	@cat Kinvey.podspec | grep "s.version\s*=\s*\"[0-9]*.[0-9]*.[0-9]*\"" | awk {'print $$3'} | sed 's/"//g' | xargs echo 'Kinvey.podspec'
	@agvtool what-version | awk '0 == NR % 2' | awk {'print $1'} | xargs echo 'Project Version  '
