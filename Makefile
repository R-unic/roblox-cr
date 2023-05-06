INSTALL_DIR = /usr/local/bin

ifeq ($(shell uname -s),Windows_NT)
  INSTALL_DIR = /usr/bin
endif

BUILD_CMD = crystal build src/main.cr -o bin/rbxcr -D i_know_what_im_doing
install:
	$(BUILD_CMD) --release
	cp bin/rbxcr $(INSTALL_DIR)/rbxcr
	chmod +x $(INSTALL_DIR)/rbxcr

build:
	$(BUILD_CMD)
