

SUBDIRS = src util

all: $(SUBDIRS)

$(SUBDIRS):
	$(MAKE) -C $@ $(MAKEOPTS) $(MAKECMDGOALS)

data: src

.PHONY: $(SUBDIRS)
