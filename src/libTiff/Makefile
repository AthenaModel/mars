#---------------------------------------------------------------------
# TITLE:
#    Makefile -- libTiff(3) Makefile
#
# AUTHOR:
#    Jon Stinzel
#
# DESCRIPTION:
#    Builds the libTiff(3) archive library.
#---------------------------------------------------------------------

#---------------------------------------------------------------------
# Settings

LIB = $(KITE_PROJECT_ROOT)/src/lib
INCLPATH = -I$(KITE_PROJECT_ROOT)/src/libTiff


# Compilation Flags

ifeq ($(KITE_OS),windows)
    OS_FLAGS =
else 
    OS_FLAGS = -fPIC
endif

CFLAGS = $(OS_FLAGS) -g -O -Wall

# Include Directory

CC  = gcc

TARGETS = $(LIB)/libTiff.a

OBJS = \
    tif_aux.o tif_close.o tif_codec.o tif_color.o \
	tif_compress.o tif_dir.o tif_dirinfo.o tif_dirread.o \
	tif_dirwrite.o tif_dumpmode.o tif_error.o tif_extension.o \
	tif_fax3.o tif_fax3sm.o tif_flush.o tif_getimage.o \
	tif_luv.o tif_lzw.o tif_next.o \
	tif_open.o tif_packbits.o tif_pixarlog.o tif_predict.o \
	tif_print.o tif_read.o tif_strip.o tif_swab.o \
	tif_thunder.o tif_tile.o tif_unix.o tif_version.o \
	tif_warning.o tif_write.o tif_zip.o

all: $(TARGETS)

$(LIB)/libTiff.a: $(OBJS)
	ar rcvs $@ $(OBJS)

%.o:%.c
	$(CC) -c $(CFLAGS) $(INCLPATH) $< -o $@

clean:
	rm -f *.o $(TARGETS)


