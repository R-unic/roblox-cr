INSTALL_DIR = /usr/local/bin

ifeq ($(shell uname -s),Windows_NT)
  INSTALL_DIR = /usr/bin
endif

BUILD_CMD = build src/main.cr -o bin/rbxcr -D i_know_what_im_doing
install:
	shards $(BUILD_CMD) --error-trace --release
	cp bin/rbxcr $(INSTALL_DIR)/rbxcr
	chmod +x $(INSTALL_DIR)/rbxcr
	crystal spec -v

test:
	crystal spec -v

dev:
	crystal $(BUILD_CMD)

trace:
	crystal $(BUILD_CMD) --error-trace
