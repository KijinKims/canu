TARGET   := prefixEditDistance-matchLimitGenerate
SOURCES  := prefixEditDistance-matchLimitGenerate.C

SRC_INCDIRS  := ../.. ../../utility/src/utility ../../stores

TGT_LDFLAGS := -L${TARGET_DIR}/lib
TGT_LDLIBS  := -l${MODULE}
TGT_PREREQS := lib${MODULE}.a
