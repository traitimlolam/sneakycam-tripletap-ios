TARGET := iphone:clang:latest:15.0
ARCHS := arm64 arm64e

FINALPACKAGE = 1
DEBUG = 0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SneakyCamTripleTap

SneakyCamTripleTap_FILES = Tweak.x
SneakyCamTripleTap_FRAMEWORKS = UIKit Foundation AudioToolbox
SneakyCamTripleTap_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable

include $(THEOS_MAKE_PATH)/tweak.mk
