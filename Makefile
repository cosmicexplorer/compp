.PHONY: all clean distclean check install

# required to build
NPM_BIN = $(shell npm bin)
FORMAT_OUT = $(NPM_BIN)/c-format
COFFEE_CC = $(NPM_BIN)/coffee

# put source inputs in src/ and make them coffee files
SRC_DIR = src
SRC = $(wildcard $(SRC_DIR)/*.coffee)
OBJ_DIR = lib/compp
OBJ = $(patsubst $(SRC_DIR)/%.coffee, $(OBJ_DIR)/%.js, $(SRC))

# "binary"
DRIVER = compp
BIN_DIR = bin
BIN_DRIVER = $(BIN_DIR)/$(DRIVER)

# setup test directories
TEST_DIR = test
TEST_IN_DIR = $(TEST_DIR)/in
TEST_OUT_DIR = $(TEST_DIR)/out
TEST_OUT_CPP_DIR = $(TEST_OUT_DIR)/cpp
TEST_OUT_COMPP_DIR = $(TEST_OUT_DIR)/compp
TEST_IN = $(wildcard $(TEST_IN_DIR)/*.c)
# these are the output of cpp
TEST_CPP_OBJ = $(patsubst $(TEST_IN_DIR)/%.c, \
	$(TEST_OUT_CPP_DIR)/%.c, $(TEST_IN))
# these are the output of compp!
TEST_COMPP_OBJ = $(patsubst $(TEST_IN_DIR)/%.c, \
	$(TEST_OUT_COMPP_DIR)/%.c, $(TEST_IN))

# lol should probs have these
DEPS = node_modules

all: $(BIN_DRIVER)

$(BIN_DRIVER): $(DEPS) $(OBJ)
	@cp $@-stub $@
	@chmod +x $@

$(OBJ_DIR)/%.js: $(SRC_DIR)/%.coffee
	$(COFFEE_CC) -o $(OBJ_DIR) -bc $<

$(DEPS):
	@echo "Installing required packages..."
	@npm install

clean:
	@rm -f $(OBJ) $(TEST_CPP_OBJ) $(TEST_COMPP_OBJ) $(BIN_DRIVER)

distclean: clean
	@rm -rf $(DEPS)

# let's make those tests
$(TEST_OUT_CPP_DIR)/%.c: $(TEST_IN_DIR)/%.c all
	cpp $< -P | $(FORMAT_OUT) - $@ -n0
# create compp's output files and diff (diff returns nonzero on different)
# compp's default output is formatted with c-format-stream within the process
$(TEST_OUT_COMPP_DIR)/%.c: $(TEST_IN_DIR)/%.c $(TEST_OUT_CPP_DIR)/%.c all
	$(BIN_DRIVER) $< -o $@
	diff $(word 2, $^) $@

check: $(TEST_COMPP_OBJ)

install:
	@npm install -g
