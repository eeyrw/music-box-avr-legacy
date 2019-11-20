# Makefile for Atmel AVR microcontrollers
# Does not generate output for debugging or simulation

# Important settings should be updated for each project.
# The rest of the makefile can usually be left alone.


#### /!\ IMPORTANT SETTINGS START HERE /!\ #####

# Fuse settings
# Some fuses can prevent future programming, be careful
# Use a fuse calculator like http://www.engbedded.com/fusecalc/
# to generate avrdude parameters
AVRDUDE_FUSES = -U lfuse:w:0xe2:m -U hfuse:w:0xd8:m -U efuse:w:0xff:m

# Device options
# Not all devices supported by avr-gcc are available in avrdude
# For example, avr-gcc may compile for attiny44a but avrdude
# only knows about attiny44
MCU = atmega328p
AVRDUDE_MCU = atmega328p

# Processor speed used for compilation
# This tells the code what speed you've selected via the
# fuses and/or external clock sources. It does not set
# the actual processor speed.
F_CPU = 16000000

# Programmer type and connection port
# Examples: avrisp2, usbtiny, stk500generic, dragon_isp, buspirate
AVRDUDE_PROGRAMMER = avrisp2
AVRDUDE_PORT = usb

# AVR tools location, specify absolute path if necessary
#AVRTOOLSDIR = /usr/local/bin/
AVRTOOLSDIR = D:/avr-gcc-9.1.0-x64-mingw/bin/

###### /!\ IMPORTANT SETTINGS END HERE /!\ ######


# Build structure
TARGET = main
BUILDDIR = builds
BUILDTARGET = $(BUILDDIR)/$(TARGET)
OBJDIR = $(BUILDDIR)/obj
DEPDIR = $(BUILDDIR)/dep
CSOURCES = $(wildcard *.c) $(wildcard */*.c)
ASOURCES = $(wildcard *.S) $(wildcard */*.S)

INCLUDE_DIRS = .
INCLUDE_DIRS += ./WavetableSynthesizer

INC_DIR  = $(patsubst %, -I%, $(INCLUDE_DIRS))


OBJECTS = $(addprefix $(OBJDIR)/, $(CSOURCES:.c=.o)) $(addprefix $(OBJDIR)/, $(ASOURCES:.S=.o))
DEPS = $(addprefix $(DEPDIR)/, $(CSOURCES:.c=.d)) $(addprefix $(DEPDIR)/, $(ASOURCES:.S=.d))

# Programmer options
AVRDUDE_FLASH = -U flash:w:$(BUILDTARGET).hex
AVRDUDE_EEPROM = -U eeprom:w:$(BUILDTARGET).eep
AVRDUDE_FLAGS = -v -p $(AVRDUDE_MCU) -c $(AVRDUDE_PROGRAMMER) -P $(AVRDUDE_PORT)

# AVR tools
FORMAT = ihex
AVRDUDE = $(AVRTOOLSDIR)avrdude
AVRSIZE = $(AVRTOOLSDIR)avr-size
OBJCOPY = $(AVRTOOLSDIR)avr-objcopy
OBJDUMP = $(AVRTOOLSDIR)avr-objdump

# Compiler options
CC = $(AVRTOOLSDIR)avr-gcc
OPTIMIZATION = s
CSTANDARD = c11
CFLAGS = -O$(OPTIMIZATION) -g -std=$(CSTANDARD) -DF_CPU=$(F_CPU)UL -DRUN_TEST -mmcu=$(MCU) $(INC_DIR)
CFLAGS += -Wl,--gc-sections -ffunction-sections -fdata-sections
DEPFLAGS = -MT $@ -MMD -MP -MF $(DEPDIR)/$*.d
REMOVE = rm -f

build: .hex .eeprom .lst .size

# Virtual target for dependency files
$(DEPDIR)/%.d: ;
ifeq ($(OS),Windows_NT)
	@if not exist $(subst /,\,$(dir $@)) md $(subst /,\,$(dir $@))
else
	@mkdir -p $(dir $@)
endif

# Don't delete dependency files
.PRECIOUS: $(DEPDIR)/%.d

# Don't rebuild deps if cleaning
ifneq ($(MAKECMDGOALS),clean)
-include $(DEPS)
endif


# Build rule for C files
# Depends on Makefile to force recompile if any Makefile options changed
$(OBJDIR)/%.o: %.c
$(OBJDIR)/%.o: %.c Makefile
ifeq ($(OS),Windows_NT)
	@if not exist $(subst /,\,$(dir $@)) md $(subst /,\,$(dir $@))
else
	@mkdir -p $(dir $@)
endif
	@echo [C]: $<
	@$(CC) $(DEPFLAGS) $(CFLAGS) $(LDFLAGS) -c -o $@ $<

# Build rule for assembler files
# Depends on Makefile to force recompile if any Makefile options changed
$(OBJDIR)/%.o: %.S
$(OBJDIR)/%.o: %.S Makefile
ifeq ($(OS),Windows_NT)
	@if not exist $(subst /,\,$(dir $@)) md $(subst /,\,$(dir $@))
else
	@mkdir -p $(dir $@)
endif
	@echo [S]: $<
	@$(CC) $(DEPFLAGS) $(CFLAGS) $(LDFLAGS) -c -o $@ $<

# Don't delete object files
.PRECIOUS: $(OBJDIR)/%.o

# Rule for creating ELF files
%.elf: $(OBJECTS)
	@echo "Linking...."
	@echo [ELF]: $@
	@$(CC) $(CFLAGS) $(OBJECTS) -o $@


# Rule for creating hex files
%.hex: %.elf
	@echo [HEX]: $@
	@$(OBJCOPY) -O $(FORMAT) -R .eeprom $< $@

# Rule for creating EEPROM files
%.eep: %.elf
	@echo [EEP]: $@
	@$(OBJCOPY) -j .eeprom --set-section-flags .eeprom=alloc,load \
	--change-section-lma .eeprom=0 -O $(FORMAT) $< $@
	
%.lst: %.elf 
	@echo [LST]: $(BUILDTARGET).lst
	@$(OBJDUMP) -h -S $(BUILDTARGET).elf > $(BUILDTARGET).lst

# Build hex file
.hex: $(BUILDTARGET).hex

# Build eeprom file
.eeprom: $(BUILDTARGET).eep

# Display the flash and RAM size
.lst: $(BUILDTARGET).lst

# Display the flash and RAM size
.size: $(BUILDTARGET).elf
	@$(AVRSIZE) --target=elf32-avr $<
	


# Write the hex and eeprom files to the device
program: $(BUILDTARGET).hex $(BUILDTARGET).eep .size
	@echo "Uploading firmware..."
	$(AVRDUDE) $(AVRDUDE_FLAGS) $(AVRDUDE_FLASH) $(AVRDUDE_EEPROM)
	@echo "Done uploading."

# Write the fuses to the device
fuses:
	@echo "Writing fuses..."
	$(AVRDUDE) $(AVRDUDE_FLAGS) $(AVRDUDE_FUSES)
	@echo "Done writing fuses."

# Delete any compiled code and dependency files
# Avoiding recursive delete due to potential for mistakes
clean:
	@echo "Cleaning..."
	-$(REMOVE) $(OBJECTS)
	-$(REMOVE) $(DEPS)
	-$(REMOVE) $(BUILDTARGET).hex $(BUILDTARGET).elf $(BUILDTARGET).eep
	-find $(BUILDDIR) -type d -empty -delete
	@echo "Done cleaning."
