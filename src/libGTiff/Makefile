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

INCLPATH = -I$(TOP_DIR)/src/libGTiff \
           -I$(TOP_DIR)/src/libTiff

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


