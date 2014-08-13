#---------------------------------------------------------------------
# TITLE:
#    Makefile -- libgeotiff(3) Makefile
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    Builds the libgeotiff(3) archive library.
#---------------------------------------------------------------------

#---------------------------------------------------------------------
# Settings

LIB = $(KITE_PROJECT_ROOT)/src/lib
INCLPATH = -I$(KITE_PROJECT_ROOT)/src/libGTiff \
           -I$(KITE_PROJECT_ROOT)/src/libTiff


# Compilation Flags

ifeq ($(KITE_OS),windows)
    OS_FLAGS =
else 
    OS_FLAGS = -fPIC
endif

CFLAGS = $(OS_FLAGS) -g -O -Wall

# Include Directory

CC  = gcc

TARGETS = $(LIB)/libGTiff.a

OBJS = \
    cpl_csv.o cpl_serv.o geo_extra.o geo_free.o geo_get.o \
    geo_names.o geo_new.o geo_normalize.o geo_print.o geo_set.o \
    geo_simpletags.o geo_strtod.o geo_tiffp.o geo_trans.o \
    geo_write.o geotiff_proj4.o xtiff.o

all: $(TARGETS)

$(LIB)/libGTiff.a: $(OBJS)
	ar rcvs $@ $(OBJS)

%.o:%.c
	$(CC) -c $(CFLAGS) $(INCLPATH) $< -o $@

clean:
	rm -f *.o $(TARGETS)


