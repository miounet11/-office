ifeq ($(filter 1.% 2.% 3.%,$(MAKE_VERSION)),)
include Makefile
else
GMAKE :=
ifneq ($(filter undefined default,$(origin GNUMAKE)),default)
GMAKE := $(GNUMAKE)
endif

ifeq ($(GMAKE),)
GMAKE := $(shell command -v gmake 2>/dev/null)
endif

ifeq ($(GMAKE),)
$(error GNU Make 4.2+ is required. Install gmake or set GNUMAKE to a compatible binary.)
endif

MAKE := $(GMAKE)
MODULE_TARGETS := $(patsubst %/Makefile,%,$(wildcard */Makefile))
GMAKE_FORWARD_FLAGS := $(filter-out - --jobserver-fds=% -j,$(MFLAGS))
GMAKE_FORWARD_GOALS := $(MAKECMDGOALS)

.PHONY: default FORCE __gmake_forward $(MODULE_TARGETS)

default: __gmake_forward

GNUmakefile: ;

$(MODULE_TARGETS): __gmake_forward ;

%: FORCE __gmake_forward ;

__gmake_forward:
	+@env -u MAKEFLAGS -u MFLAGS -u MAKELEVEL MAKE="$(MAKE)" $(MAKE) $(GMAKE_FORWARD_FLAGS) $(MAKEOVERRIDES) $(GMAKE_FORWARD_GOALS)

FORCE:
endif
