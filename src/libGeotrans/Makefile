#---------------------------------------------------------------------
# TITLE:
#    Makefile -- libGeotrans(3) Makefile
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Builds the libGeotrans(3) archive library.
#---------------------------------------------------------------------

#---------------------------------------------------------------------
# Settings

KITE_OS           = $(strip $(shell kite info -os))
KITE_PROJECT_ROOT = $(strip $(shell kite info -root))

LIB = $(KITE_PROJECT_ROOT)/src/lib
INCLPATH = -I$(KITE_PROJECT_ROOT)/src/include/geotrans

# Compilation Flags

ifeq ($(KITE_OS),windows)
    OS_FLAGS = -mnop-fun-dllimport -pipe -fomit-frame-pointer
else 
    OS_FLAGS = -fPIC
endif

CFLAGS = $(OS_FLAGS) -g -O -ansi -Wall 

# Include Directory

CC  = gcc


TARGETS = $(LIB)/libGeotrans.a

OBJS = \
	mgrs.o polarst.o tranmerc.o ups.o utm.o

all: $(TARGETS)

$(LIB)/libGeotrans.a: $(OBJS)
	ar rcvs $@ $(OBJS)

%.o:%.c
	$(CC) -c $(CFLAGS) $(INCLPATH) $< -o $@

clean:
	rm -f *.o $(TARGETS)


