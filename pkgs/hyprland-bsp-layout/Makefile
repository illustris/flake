PLUGIN_NAME=hyprland-bsp-layout

SOURCE_FILES=$(wildcard *.cpp)

HYPRLAND_HEADERS ?= /usr

compile:
	$(CXX) -shared -fPIC --no-gnu-unique $(SOURCE_FILES) -o $(PLUGIN_NAME).so -g \
		`pkg-config --cflags pixman-1 libdrm` \
		-I"$(HYPRLAND_HEADERS)" \
		-I"$(HYPRLAND_HEADERS)/hyprland/protocols" \
		-std=c++23

clean:
	rm -f *.so
