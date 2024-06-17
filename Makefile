# Get current working directory
CWD := $(shell pwd)

# Collect all the source code files in this project
FILE_LIST := $(shell find ./ -type f -regex ".*\.\(ino\|cpp\|c\|h\|hpp\|hh\)$$")
FILE_LIST_STRING := $(subst $(space), ,$(FILE_LIST))

# Set configuration flags
_IDF_VERSION := $(or ${version},4.4)
_IDF_PORT := $(or ${port},ttyUSB0)

# Extract saved configurations from .config.yaml
IDF_VERSION = $(shell yq -r .IDF-VERSION $(CWD)/.config.yaml)
IDF_PORT = $(shell yq -r .PORT $(CWD)/.config.yaml)
DOCKER_IMAGE =$(shell yq -r .DOCKER_IMAGE $(CWD)/.config.yaml)

# Docker
DOCKER_CMD = --rm -v $(CWD):/project -w /project espressif/idf-local:release-v$(IDF_VERSION)

# Setup and Run Clang-Format
CLANG_FORMAT_CMD = clang-format --verbose -i --style=file $(FILE_LIST_STRING)

# Setup and Run CppCheck
CPPCHECK_CMD = cppcheck --enable=all --suppressions-list=./error-suppress-list.txt .

# Default target: build the executable
all: build

# Help target: show available targets and their descriptions
.PHONY: help
help:
	@echo "Available make Target Options:"
	@echo "  - help:                          Show Help"
	@echo "  - config:                        Configure Project & Install Project Dependencies"
	@echo "    - version=<idf-version>        idf-version: 4.4 ( Default )"
	@echo "    - port=<flash-port>            port: ttyUSB0 ( Default )"
	@echo "  - format:                        Format Source Code Files"
	@echo "  - cppcheck:                      Apply CppCheck"
	@echo "  - build:                         Compile/Build Project"
	@echo "  - flash:                         Flash Executable"
	@echo "  - test:                          Run Tests"
	@echo "  - clean:                         Remove Compiled Files"
	@echo " "
	@echo "USAGE:"
	@echo "  - '$$ make' OR '$$ make build'"
	@echo "  - '$$ make config version=5.1 port=ttyUSBxxx'" 
	@echo " "
	@echo "NOTE:"
	@echo "  - To stop build started by make, Please press CTRL + z"
	@echo "  - Configure the project as per your requirements or use the default settings"
	@echo "  - Please use ROOT priviliges, if docker is configured/installed by ROOT USER"
	@echo " "

# Install Project Dependencies
.PHONY: config
config:
	@echo "Configuring Project ... "
	@echo "IDF-VERSION: $(_IDF_VERSION)" > $(CWD)/.config.yaml
	@echo "PORT: $(_IDF_PORT)" >> $(CWD)/.config.yaml
	@echo "Project is configured to use IDF-VERSION: $(_IDF_VERSION) and Serial PORT: $(_IDF_PORT)"
	@echo " "
	@echo "Installing Project Dependencies ... "
	@apt-get update
	@wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
	@chmod a+x /usr/local/bin/yq
	@docker build -t espressif/idf-local:release-v$(_IDF_VERSION) --build-arg IDF_VERSION=$(_IDF_VERSION) ./make-idf/docker/
	@echo "DOCKER_IMAGE: espressif/idf-local:release-v$(_IDF_VERSION)" >> $(CWD)/.config.yaml

# Display project info
.PHONY: info
info:
	@echo "Project Info ... "
	@echo "    - IDF_VERSION: v$(IDF_VERSION)"
	@echo "    - BRANCH: $(shell git branch --show-current)"
	@echo "    - CURRENT_COMMIT_SHA: $(shell git rev-parse --short HEAD)"
	@echo "    - Serial PORT: $(IDF_PORT)"
	@echo " "

# Format Source Code Files
.PHONY: format
format:
	@echo "Applying Formatting ... "
	@docker run $(DOCKER_CMD) $(CLANG_FORMAT_CMD)

# Apply CppCheck
.PHONY: cppcheck
cppcheck:
	@echo "Applying CppCheck ... "
	@docker run $(DOCKER_CMD) $(CPPCHECK_CMD)

# Build the executable
.PHONY: build
build: info
	@echo "Building Project ... "
	@docker run $(DOCKER_CMD) idf.py build

# Flash the executable
.PHONY: flash
flash: info
	@echo "Flashing Image ... "
	@docker run --privileged -v /dev:/dev $(DOCKER_CMD) idf.py flash -p /dev/$(IDF_PORT)

# Run Tests
.PHONY: test
test:
	@echo "Running Tests ... "
	@echo "Need to call the CMAKE gtest/pytest targets here ... "

# Clean Project
.PHONY: clean
clean: info
	@echo "Cleaning Project ... "
	@docker run $(DOCKER_CMD) idf.py fullclean
	@docker rmi $(DOCKER_IMAGE) -f
	@rm $(CWD)/.config.yaml
