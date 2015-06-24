.PHONY: all clean distclean check install
.DELETE_ON_ERROR:

# dependencies
DEPS := node_modules
NPM_BIN := $(shell npm bin)
FORMAT_OUT := $(NPM_BIN)/c-format
COFFEE_CC := $(NPM_BIN)/coffee

# source directories
SRC_DIR := src
SRC := $(wildcard $(SRC_DIR)/*.coffee)
OBJ_DIR := lib/compp
OBJ := $(patsubst $(SRC_DIR)/%.coffee, $(OBJ_DIR)/%.js, $(SRC))

# output binaries
DRIVER := compp
BIN_DIR := bin
BIN_DRIVER := $(BIN_DIR)/$(DRIVER)


### BUILDING
all: $(BIN_DRIVER)

$(BIN_DRIVER): $(DEPS) $(OBJ)
	@cp $@-stub $@
	@chmod +x $@

$(OBJ_DIR)/%.js: $(SRC_DIR)/%.coffee
	$(COFFEE_CC) -o $(OBJ_DIR) -bc $<

$(DEPS):
	@echo "Installing required packages..."
	@npm install


### CLEANUP
clean:
	@rm -f $(OBJ)
	@rm -f $(TEST_CPP_OBJ)
	@rm -f $(TEST_COMPP_OBJ)
	@rm -f $(BIN_DRIVER)
	@rm -f $(UNIT_TEST_OUTPUTS)
	@rm -f $(INTEGRATION_TEST_OUTPUTS)

distclean: clean
	@rm -rf $(DEPS)


### TESTING
TEST_DIR := test
TEST_UTILS := $(TEST_DIR)/test-utils.coffee

# unit testing
UNIT_TEST_DIR := $(TEST_DIR)/unit
UNIT_TEST_DIRS := $(wildcard $(UNIT_TEST_DIR)/*)
UNIT_TEST_OUTPUTS := $(addsuffix /output, $(UNIT_TEST_DIRS))
# the .js file requirement is so syntax errors in the source file are checked
# you can have other intermediate files, but they should be cleaned up by the
# test, even if the test terminates with an error, and a successful test should
# have no other files
$(UNIT_TEST_DIR)/%/output: $(UNIT_TEST_DIR)/%/test.coffee \
$(UNIT_TEST_DIR)/%/input $(OBJ_DIR)/%.js $(TEST_UTILS)
	@echo -n "unit-test: "
	@echo $@ | perl -pe 's/(^.*unit\/|\/output$$)//g'
	$(COFFEE_CC) $< $(word 2, $^) > $@

# # integration testing (not happening rn)
INTEGRATION_TEST_DIR := $(TEST_DIR)/integration
INTEGRATION_TEST_DIRS := $(wildcard $(INTEGRATION_TEST_DIR)/*)
INTEGRATION_TEST_OUTPUTS := $(addsuffix /output, $(INTEGRATION_TEST_DIRS))
$(INTEGRATION_TEST_DIR)/%/output: $(INTEGRATION_TEST_DIR)/%/test.coffee \
$(INTEGRATION_TEST_DIR)/%/input $(TEST_UTILS) all
	@echo -n "integration-test: "
	@echo $@ | perl -pe 's/(^.*integration\/|\/output$$)//g'
	$(COFFEE_CC) $< $(word 2, $^) > $@

check: $(UNIT_TEST_OUTPUTS) $(INTEGRATION_TEST_OUTPUTS)

### INSTALL
install:
	@npm install -g
