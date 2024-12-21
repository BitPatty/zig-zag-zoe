# SDL
SDL_SRC_DIR := $(PWD)/submodules/SDL
SDL_BUILD_DIR := $(PWD)/.out/sdl
SDL_INCLUDE_DIR := $(SDL_BUILD_DIR)/include
SDL_LIB_DIR := $(SDL_BUILD_DIR)/lib

# Zig
ZIG := zig
ZIG_SRC := $(wildcard src/**/*.zig)
ZIG_CACHE_DIR := $(PWD)/.zig-cache
ZIG_BUILD_DIR := $(PWD)/.out/app
ZIG_BINARY_NAME := zig-zag-zoe

# Flatpak
FLATPAK_CONFIG_PATH := $(PWD)/zig-zag-zoe.flatpak.yml
FLATPAK_BUILD_DIR := $(PWD)/.out/flatpak

all: sdl app clean 

.PHONY: flatpak
flatpak: $(FLATPAK_BUILD_DIR)
$(FLATPAK_BUILD_DIR): $(ZIG_BUILD_DIR)/$(ZIG_BINARY_NAME)
	rm -rf $(FLATPAK_BUILD_DIR)
	flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
	flatpak-builder --user --install-deps-from=flathub --force-clean ${FLATPAK_BUILD_DIR} ${FLATPAK_CONFIG_PATH}

.PHONY: app
app: $(ZIG_BUILD_DIR)/$(ZIG_BINARY_NAME) sdl
$(ZIG_BUILD_DIR)/$(ZIG_BINARY_NAME): $(ZIG_SRC)
	rm -rf $(ZIG_CACHE_DIR)
	rm -rf $(ZIG_BUILD_DIR)
	mkdir -p $(ZIG_BUILD_DIR)
	$(ZIG) build-exe \
	  -Dtarget=x86_64-linux-gnu \
	  -Doptimize=ReleaseSmall \
	  -femit-bin="$@" \
	  -I$(SDL_INCLUDE_DIR) \
	  -L$(SDL_LIB_DIR) \
	  -weak-lSDL3 \
	  -lc \
	  src/main.zig

.PHONY: sdl
sdl: $(SDL_BUILD_DIR)
$(SDL_BUILD_DIR): $(SDL_SRC_DIR)
	rm -rf $(SDL_BUILD_DIR)
	git submodule update
	cd $(SDL_SRC_DIR) && \
	rm -rf build && \
	cmake -S . -B build \
	  -DCMAKE_C_COMPILER=gcc \
	  -DCMAKE_CXX_COMPILER=/usr/bin/g++ \
	  -DSDL_STATIC=OFF \
	  -DSDL_SHARED=ON \
	  -DSDL_LIBC=ON \
	  -DSDL_DBUS=OFF \
	  -DSDL_LIBURING=OFF \
	  -DSDL_DISKAUDIO=OFF \
	  -DSDL_DUMMYAUDIO=OFF \
	  -DSDL_DUMMYVIDEO=ON \
	  -DSDL_IBUS=OFF \
	  -DSDL_OPENGL=OFF \
	  -DSDL_OPENGLES=OFF \
	  -DSDL_PTHREADS=ON \
	  -DSDL_PTHREADS_SEM=ON \
	  -DSDL_OSS=OFF \
	  -DSDL_ALSA=OFF \
	  -DSDL_ALSA_SHARED=OFF \
	  -DSDL_JACK=OFF \
	  -DSDL_JACK_SHARED=OFF \
	  -DSDL_PIPEWIRE=OFF \
	  -DSDL_PIPEWIRE_SHARED=OFF \
	  -DSDL_PULSEAUDIO=OFF \
	  -DSDL_PULSEAUDIO_SHARED=OFF \
	  -DSDL_SNDIO=OFF \
	  -DSDL_SNDIO_SHARED=OFF \
	  -DSDL_WAYLAND_LIBDECOR_SHARED=OFF \
	  -DSDL_RPI=OFF \
	  -DSDL_ROCKCHIP=OFF \
	  -DSDL_COCOA=OFF \
	  -DSDL_DIRECTX=OFF \
	  -DSDL_XINPUT=OFF \
	  -DSDL_WASAPI=OFF \
	  -DSDL_RENDER_D3D=OFF \
	  -DSDL_RENDER_D3D11=OFF \
	  -DSDL_RENDER_D3D12=OFF \
	  -DSDL_RENDER_METAL=OFF \
	  -DSDL_RENDER_GPU=ON \
	  -DSDL_VIVANTE=OFF \
	  -DSDL_VULKAN=ON \
	  -DSDL_RENDER_VULKAN=ON \
	  -DSDL_METAL=OFF \
	  -DSDL_OPENVR=OFF \
	  -DSDL_KMSDRM=OFF \
	  -DSDL_KMSDRM_SHARED=OFF \
	  -DSDL_OFFSCREEN=OFF \
	  -DSDL_DUMMYCAMERA=OFF \
	  -DSDL_HIDAPI=ON \
	  -DSDL_HIDAPI_LIBUSB=OFF \
	  -DSDL_HIDAPI_LIBUSB_SHARED=OFF \
	  -DSDL_HIDAPI_JOYSTICK=OFF \
	  -DSDL_VIRTUAL_JOYSTICK=OFF \
	  -DSDL_LIBUDEV=ON \
	  -DSDL_ASAN=OFF \
	  -DSDL_CCACHE=ON \
	  -DSDL_CLANG_TIDY=OFF \
	  -DSDL_GPU_DXVK=OFF && \
	cmake --build build && \
	cmake --install build --prefix=$(SDL_BUILD_DIR)

.PHONY: clean
clean:
	rm -rf $(FLATPAK_BUILD_DIR) $(ZIG_BUILD_DIR) $(SDL_BUILD_DIR)
