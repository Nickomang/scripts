#OBJS (which files to compile)
OBJS = 01_hello_SDL.cpp

#CC (which compiler to use)
CC = g++

#OBJ_NAME (name of executable)
OBJ_NAME = 01_hello_SDL

#COMPILER_FLAGS (additional compilation options)
COMPILER_FLAGS=

#LINKER_FLAGS (libraries linking against)
LINKER_FLAGS = `sdl2-config --cflags --libs`

#Compilation Target
all : $(OBJS)
	$(CC) -o $(OBJ_NAME) $(OBJS) $(LINKER_FLAGS) $(COMPILER_FLAGS)
