./build/dma.gb: ./build/main.o ./build/joypad.o 
	../rgblink ./build/main.o ./build/joypad.o -o ./build/dma.gb
	../rgbfix -v -p 0 ./build/dma.gb
	../BGB/bgb.exe ./build/dma.gb

./build/main.o: main.asm
	../rgbasm main.asm -o ./build/main.o

./build/joypad.o: joypad.asm
	../rgbasm joypad.asm -o ./build/joypad.o

clean:
	rm ./build/*.o