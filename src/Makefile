BUILD=../build

LD=ld65
LDOPT=-v -vm
CC=cc65
CCOPT=-D BBC_CLIB -g -T -O -Or -r -I libsrc/bbc -I libsrc/runtime
AS=ca65
ASOPT=-D BBC_CLIB
AR=ar65

RTDIR=libsrc/runtime
COMDIR=libsrc/common
BBCDIR=libsrc/bbc
RTSRCS=$(wildcard $(RTDIR)/*.s) 
COMSRCS=$(shell find $(COMDIR) -iname "*.s" -o -iname "*.c")
BBCSRCS=$(shell find $(BBCDIR) -iname "*.s" -o -iname "*.c")
SRCSNOP=$(COMSRCS:$(COMDIR)/%=%) $(RTSRCS:$(RTDIR)/%=%) $(BBCSRCS:$(BBCDIR)/%=%)

WRK=$(BUILD)/libwrk


OBJS=$(addprefix $(WRK)/, $(patsubst %.c, %.o, $(patsubst %.s,%.o,$(SRCSNOP))))
INFOS=$(patsubst %.o, %.info, $(OBJS))

CLIB_RTIMPORT=$(WRK)/clib_imports.inc
CLIB_RTJUMPS=$(WRK)/clib_imports_jmp.inc
CLIB_OBJS_LST=$(WRK)/clib_include_objs.lst
CLIB_STUBS_LST=$(WRK)/clib_include_lib_objs.lst
CLIB_INCS= $(CLIB_RTIMPORT) $(CLIB_RTJUMPS) $(CLIB_OBJS_LST) $(CLIB_STUBS_LST)


X:=$(shell mkdir -p $(BUILD))
X:=$(shell mkdir -p $(WRK))
X:=$(shell mkdir -p $(WRK)/oslib)


.PHONY:clean all 

all:: $(OBJS) $(BUILD)/clib.rom $(WRK)/clib_stubs.s $(BUILD)/clib.lib | $(WRK) $(WRK)/oslib

clean::
	rm -r libwrk
	rm $(BUILD)/clib.rom
	rm $(BUILD)/clib.lib
	rm $(BUILD)/clib.map


$(WRK)/clib_rom.o: clib_rom.s $(CLIB_INCS)
	$(AS) $(ASOPT) -I $(WRK) -o $@ $<

$(CLIB_INCS): $(RTSRCS) clib_imports.pl $(WRK) $(OBJS) $(INFOS) 
	perl clib_imports.pl $(CLIB_RTIMPORT) $(CLIB_RTJUMPS) $(CLIB_OBJS_LST) $(CLIB_STUBS_LST) $(INFOS)


$(WRK)/%.info: $(WRK)/%.o
	od65 --dump-all $< >$@

$(WRK)/oslib/%.info: $(WRK)/oslib/%.o
	od65 --dump-all $< >$@

$(WRK)/%.o: $(RTDIR)/%.s | $(WRK)
	$(AS) $(ASOPT) -o $@ $<

$(WRK)/%.o: $(COMDIR)/%.s | $(WRK)
	$(AS) $(ASOPT) -o $@ $<

$(WRK)/%.o: $(BBCDIR)/%.s | $(WRK)
	$(AS) $(ASOPT) -o $@ $<

$(WRK)/oslib/%.o: $(BBCDIR)/oslib/%.s | $(WRK)/oslib
	$(AS) $(ASOPT) -o $@ $<

$(WRK)/%.o: $(WRK)/%.s
	$(AS) $(ASOPT) -o $@ $<

$(WRK)/%.s: $(RTDIR)/%.c
	$(CC) $(CCOPT) -o $@ $<

$(WRK)/%.s: $(COMDIR)/%.c
	$(CC) $(CCOPT) -o $@ $<

$(WRK)/%.s: $(BBCDIR)/%.c
	$(CC) $(CCOPT) -o $@ $<

$(WRK)/oslib/%.s: $(BBCDIR)/oslib/%.c
	$(CC) $(CCOPT) -o $@ $<

$(WRK)/clib_stubs.s: $(BUILD)/clib.map clib_stubs.pl
	perl clib_stubs.pl $(BUILD)/clib.map $(WRK)/clib_stubs.s

$(BUILD)/clib.rom $(BUILD)/clib.map &: $(WRK)/clib_rom.o $(RTOBJS) clib_rom.cfg
	-rm $(BUILD)/clib_rom.tmp.lib
	$(AR) a $(BUILD)/clib_rom.tmp.lib $(shell cat $(CLIB_OBJS_LST))
	$(LD) $(LDOPT) -m $(BUILD)/clib.map -C clib_rom.cfg -o $(BUILD)/clib.rom $(WRK)/clib_rom.o $(BUILD)/clib_rom.tmp.lib

$(BUILD)/clib.lib: $(WRK)/clib_stubs.o $(CLIB_STUBS_LST)
	-rm $(BUILD)/clib.lib >/dev/null
	$(AR) a $@ $(WRK)/clib_stubs.o
	$(AR) a $@ $(shell cat $(CLIB_STUBS_LST))
