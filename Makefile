#
# Instance values, command line user specifiable
#

CONFIG   = max
CPPFLAGS = 
CXXFLAGS = 
LDFLAGS  = 

PREFIX = $(DESTDIR)/usr/local
LIBDIR = $(PREFIX)/lib
INCLUDEDIR = $(PREFIX)/include

#
# Tools
#

CC       = g++
LD       = g++
AR       = ar
LDCONFIG = ldconfig
#
# Build values
#

LIBRARY_NAME     = zmqpp
VERSION_API      = 1
VERSION_REVISION = 0
VERSION_AGE      = 0

#
# Paths
#

TESTS_DIR    = tests
LIBRARY_DIR  = zmq

SRC_PATH     = ./src
TESTS_PATH   = $(SRC_PATH)/$(TESTS_DIR)
LIBRARY_PATH = $(SRC_PATH)/$(LIBRARY_DIR)

BUILD_PATH   = ./build/$(CONFIG)
OBJECT_PATH  = $(BUILD_PATH)/obj

#
# Core values
#

APP_VERSION    = $(VERSION_API).$(VERSION_REVISION).$(VERSION_AGE)
APP_DATESTAMP  = $(shell date '+"%Y-%m-%d %H:%M"')

LIBRARY_SHARED = lib$(LIBRARY_NAME).so
LIBRARY_ARCHIVE = lib$(LIBRARY_NAME).a
TESTS_TARGET   = $(LIBRARY_NAME)-tests

CONFIG_FLAGS =
ifeq ($(CONFIG),debug)
	CONFIG_FLAGS = -g -fno-inline -ftemplate-depth-1000
endif
ifeq ($(CONFIG),valgrind)
	CONFIG_FLAGS = -g -O1 -DNO_DEBUG_LOG -DNtestO_TRACE_LOG
endif
ifeq ($(CONFIG),max)
	CONFIG_FLAGS = -O3 -funroll-loops -ffast-math -finline-functions -fomit-frame-pointer -DNDEBUG
endif
ifeq ($(CONFIG),release)
	CONFIG_FLAGS = -O3 -funroll-loops -ffast-math -finline-functions -fomit-frame-pointer -DNO_DEBUG_LOG -DNO_TRACE_LOG -DNDEBUG
endif

COMMON_FLAGS = -MMD -std=c++0x -pipe -Wall -fPIC \
	-DBUILD_ENV=$(CONFIG) \
	-DBUILD_VERSION='"$(APP_VERSION)"' \
	-DBUILD_VERSION_API=$(VERSION_API) \
	-DBUILD_VERSION_REVISION=$(VERSION_REVISION) \
	-DBUILD_VERSION_AGE=$(VERSION_AGE) \
	-DBUILD_DATESTAMP='$(APP_DATESTAMP)' \
	-I$(SRC_PATH)

COMMON_LIBS = -lzmq

LIBRARY_LIBS =  

TEST_LIBS = -L$(BUILD_PATH) \
	-l$(LIBRARY_NAME) \
	-lboost_unit_test_framework 

ifeq ($(LOADTEST),true)
	CONFIG_FLAGS := $(CONFIG_FLAGS) -DLOADTEST
	TEST_LIBS := $(TEST_LIBS) -lboost_thread
endif

ALL_LIBRARY_OBJECTS := $(patsubst $(SRC_PATH)/%.cpp, $(OBJECT_PATH)/%.o, $(shell find $(LIBRARY_PATH) -iname '*.cpp'))

ALL_LIBRARY_INCLUDES := $(shell find $(LIBRARY_PATH) -iname '*.hpp')

ALL_TEST_OBJECTS := $(patsubst $(SRC_PATH)/%.cpp, $(OBJECT_PATH)/%.o, $(shell find $(TESTS_PATH) -iname '*.cpp'))

TEST_SUITES := ${addprefix test-,${sort ${shell find ${TESTS_PATH} -iname *.cpp | xargs grep BOOST_AUTO_TEST_SUITE\( | sed 's/.*BOOST_AUTO_TEST_SUITE( \(.*\) )/\1/' }}}

#error
# BUILD Targets - StandardisBOOST_AUTO_TEST_SUITE( sanity )
#

.PHONY: check clean install installcheck uninstall test $(TEST_SUITES)

all: $(LIBRARY_SHARED) $(LIBRARY_ARCHIVE)
	@echo "use make check to test the build"

check: test

install: $(LIBRARY_SHARED) $(LIBRARY_ARCHIVE)
	-mkdir $(INCLUDEDIR)/zmq
	cp $(ALL_LIBRARY_INCLUDES) $(INCLUDEDIR)/zmq
	chmod 644 $(INCLUDEDIR)/zmq/*.hpp
	cp $(BUILD_PATH)/$(LIBRARY_ARCHIVE) $(LIBDIR)/$(LIBRARY_ARCHIVE)
	cp $(BUILD_PATH)/$(LIBRARY_SHARED) $(LIBDIR)/$(LIBRARY_SHARED).$(APP_VERSION)
	ln -sf $(LIBRARY_SHARED).$(APP_VERSION) $(LIBDIR)/$(LIBRARY_SHARED).$(VERSION_API)
	ln -sf $(LIBRARY_SHARED).$(APP_VERSION) $(LIBDIR)/$(LIBRARY_SHARED)
	chmod 755 $(LIBDIR)/$(LIBRARY_ARCHIVE) $(LIBDIR)/$(LIBRARY_SHARED)
	$(LDCONFIG)
	@echo "use make installcheck to test the install"
	
installcheck: $(TESTS_TARGET)
	$(BUILD_PATH)/$(TESTS_TARGET)

uninstall:
	rm -r $(INCLUDEDIR)/zmq
	rm $(LIBDIR)/$(LIBRARY_ARCHIVE)
	rm $(LIBDIR)/$(LIBRARY_SHARED).$(APP_VERSION)
	rm $(LIBDIR)/$(LIBRARY_SHARED).$(VERSION_API)
	rm $(LIBDIR)/$(LIBRARY_SHARED)

clean:
	rm -r $(BUILD_PATH)

#
# BUILD Targets
#

$(LIBRARY_SHARED): $(ALL_LIBRARY_OBJECTS)
	$(LD) $(LDFLAGS) -shared -rdynamic -o $(BUILD_PATH)/$@ $^ $(LIBRARY_LIBS) $(COMMON_LIBS)


$(LIBRARY_ARCHIVE): $(ALL_LIBRARY_OBJECTS)
	$(AR) crf $(BUILD_PATH)/$@ $^


$(TESTS_TARGET): $(ALL_TEST_OBJECTS) $(LIBRARY_SHARED)
	$(LD) $(LDFLAGS) -o $(BUILD_PATH)/$(TESTS_TARGET) $(ALL_TEST_OBJECTS) $(TEST_LIBS) $(COMMON_LIBS) 


$(TEST_SUITES): $(TESTS_TARGET)
	$(BUILD_PATH)/$(TESTS_TARGET) --log_level=message --run_test=$(patsubst test-%,%,$@)


test: $(TESTS_TARGET)
	@echo "running all test targets ($(TEST_SUITES))"
	LD_LIBRARY_PATH=$(BUILD_PATH):$(LD_LIBRARY_PATH) $(BUILD_PATH)/$(TESTS_TARGET)
	

#
# Dependencies
# We don't care if they don't exist as the object won't have been built
#

-include $(patsubst %.o,%.d,$(ALL_LIBRARY_OBJECTS) $(ALL_TEST_OBJECTS))

#
# Object file generation
#

$(OBJECT_PATH)/%.o: $(SRC_PATH)/%.cpp
	-mkdir -p $(dir $@)
	$(CC) $(CPPFLAGS) $(CXXFLAGS) $(COMMON_FLAGS) $(CONFIG_FLAGS) -c -o $@ $<

