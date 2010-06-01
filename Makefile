TWEAK_NAME = quickshottr
quickshottr_OBJCC_FILES =  Tweak.mm
quickshottr_FRAMEWORKS = CoreGraphics UIKit
GO_EASY_ON_ME = 1

include framework/makefiles/common.mk
include framework/makefiles/aggregate.mk
include framework/makefiles/tweak.mk
