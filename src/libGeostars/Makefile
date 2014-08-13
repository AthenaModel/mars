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

LIB = $(KITE_PROJECT_ROOT)/src/lib
INCLPATH = -I$(KITE_PROJECT_ROOT)/src/include/geostars

# Compilation Flags

ifeq ($(KITE_OS),windows)
    OS_FLAGS =
else 
    OS_FLAGS = -fPIC
endif

CFLAGS = $(OS_FLAGS) -g -O -Wall

# Include Directory

CC  = gcc

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


