.SUFFIXES:
.PRECIOUS: %.fcd %.fpr %.fsm %.res xh430.out
.PHONY: main flash code reset p- p+ rh parm arc dump ram bug setbug getbug showbug clean help test tools

PREFIX=/opt/cdk4msp/bin/msp430-

AS=$(PREFIX)as
LD=$(PREFIX)ld
OBJCOPY=$(PREFIX)objcopy
OBJDUMP=$(PREFIX)objdump
PARJTAG=$(PREFIX)parjtag

CODE=0xF000
PARM=0x1000

ARAM=0x0200
SIZE=0x0100

UPARM=0x1010
APARM=0x1090
SPARM=0x000C

ASIM=0x1080
SSIM=0x0080

FPARM="%c\n%d\n%d\n%d\n%d\n%d\n"

FACTOR=.265

OCFLAGS=--change-section-address .data=0x1080

ASFLAGS=--fatal-warnings -mmcu=msp430x1122
#ASFLAGS+=-defsym DEBUG=1
#ASFLAGS+=-defsym DSIM=1
#ASFLAGS+=-defsym DIBIT=1
#ASFLAGS+=-defsym FARC=1
ASFLAGS+=-defsym FDHIS=1
ASFLAGS+=-defsym FDPAR=1
ASFLAGS+=-defsym FLIQO=1
#ASFLAGS+=-defsym FDUMP=1

LDFLAGS=-nostdlib -mmsp430x1122

TESTS:=$(patsubst %.par,%.tst,$(wildcard tst/test??.par))

GRN:="\033[0;32m"
YEL:="\033[0;33m"
RED:="\033[0;31m"
END:="\033[0m"

main:		xh430.out
flash:		xh430.fcd
code:		xh430.out
	$(OBJDUMP) -d xh430.out
reset:
	$(PARJTAG) -r

p-:			tools
	printf $(FPARM) - 740 700 400 56 0 >parm.cfg
	@make parm.fpr
p+:			tools
	printf $(FPARM) + 740 700 400 56 0 >parm.cfg
	@make parm.fpr
rh:			tools
	printf $(FPARM) r 650 650 468 38 0 >parm.cfg
	@make parm.fpr

parm:		tools
	$(PARJTAG) -u$(UPARM) -s$(SPARM) -b | ./memdump
arc:		tools
	$(PARJTAG) -u$(APARM) -s$(SPARM) -b | ./memdump
dump:		tools
	$(PARJTAG) -u$(CODE) -s$(SIZE) -b | ./memdump
ram:		tools
	$(PARJTAG) -u$(ARAM) -s$(SIZE) -b | ./memdump

bug:		tools
	make dump >bug.txt
	make code >>bug.txt
setbug:		bugcode.hex bugparm.hex
	$(PARJTAG) -m -p bugcode.hex
	$(PARJTAG) --eraseinfo -p -r bugparm.hex
getbug:
	$(PARJTAG) -u$(CODE) -s0x1000 -b >bugcode.bin
	$(PARJTAG) -u$(PARM) -s$(SIZE) -b >bugparm.bin
showbug:	parm.txt dump.txt

clean:
	$(RM) -rf memdump mkparm getcycle *.o *.out *.txt *.hex *.res *.cfg *.bin *.fcd *.fpr *.fsm *.cyc

help:
	@echo "Targets:"
	@echo " compile: main, clean"
	@echo " information: code"
	@echo " test: test"
	@echo " modification: flash, reset, p-, p+, rh"
	@echo " investigation: parm, arc, dump, ram"
	@echo " bug mgt: bug, setbug, getbug, showbug"

test:	$(TESTS)
tools:	memdump mkparm getcycle

bugcode.hex:	bugcode.bin
	$(OBJCOPY) -I binary -O ihex --change-addresses $(CODE) $< $@
bugparm.hex:	bugparm.bin
	$(OBJCOPY) -I binary -O ihex --change-addresses $(PARM) $< $@
dump.txt:		bugcode.bin tools
	./memdump <$< >$@
parm.txt:		bugcode.bin tools
	dd if=$< bs=1 count=16 skip=16 2>/dev/null | ./memdump >$@

%:		%.c
	$(CC) $(CFLAGS) $< -o $@
%.o:	%.s
	$(AS) $(ASFLAGS) $< -o $@
%.out:	%.o
	$(LD) $(LDFLAGS) $< -o $@
%.hex:	%.out
	$(OBJCOPY) $(OCFLAGS) -O ihex $< $@
%.bin:	%.out
	$(OBJCOPY) $(OCFLAGS) -O binary $< $@
%.cfg:	%.par
	printf $(FPARM) $(shell cat $< | sed -n -e '1s/^#//p') >$@
%.cyc:	%.hex tools
	cat $< | ./getcycle >$@
%.fpr:	%.cfg tools
	cat $< | ./mkparm | $(PARJTAG) --erase=$(PARM) -p -r -
	-rm *.fpr 2>/dev/null || true
	touch $@
%.fsm:	%.hex
	$(PARJTAG) --erase=$(ASIM) -p -r $<
	-rm *.fsm 2>/dev/null || true
	touch $@
%.fcd:	%.hex
	$(PARJTAG) -m -p -r $<
	-rm *.fcd 2>/dev/null || true
	touch $@
%.res:	%.fpr %.fsm %.cyc xh430.fcd
	sleep $(shell printf %.0f $$(echo "$$(cat $*.cyc) * $(FACTOR)" | bc))
	@make ram >$@
%.tst:	%.res
	@NBG=$$(cat $*.par | sed -e '/^#/d' | wc -l); \
	NBR=$$(cat $*.par | sed -e '/^#/d' | grep -F -x -f $< | wc -l); \
	echo -n ; \
	if ! grep -q -F STOP $<; then \
		echo $(YEL)$*": not enought time to finish"$(END); \
	elif \[ $${NBG} -eq $${NBR} \]; then \
		echo $(GRN)$*": ok"$(END); \
	else \
		echo $(RED)$*": failed"$(END); \
	fi
