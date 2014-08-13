#---------------------------------------------------------------------
# TITLE:
#    Makefile -- libGeostars(3) Makefile
#
# AUTHOR:
#    Jon Stinzel
#
# DESCRIPTION:
#    Builds the libGeostars(3) archive library.
#---------------------------------------------------------------------

#---------------------------------------------------------------------
# Settings

TOP_DIR = ../..

include $(TOP_DIR)/MakeDefs

LIB = $(TOP_DIR)/src/lib

# Compilation Flags

ifeq ($(MARS_OS),win)
    OS_FLAGS =
else 
    OS_FLAGS = -fPIC
endif

CFLAGS = $(OS_FLAGS) -g -O -Wall

# Include Directory

CC  = gcc

INCLPATH = -I$(TOP_DIR)/src/include/geostars

TARGETS = $(LIB)/libGeostars.a

OBJS = \
	geoEllips.o geoPoint.o geoMag.o


all: $(TARGETS)

$(LIB)/libGeostars.a: $(OBJS)
	ar rcvs $@ $(OBJS)

%.o:%.c
	$(CC) -c $(CFLAGS) $(INCLPATH) $< -o $@

clean:
	rm -f *.o $(TARGETS)


