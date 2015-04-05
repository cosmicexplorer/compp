DRIVER = compp.coffee

TEST_OBJ = test/test1_out_cpp.c
TEST_COMP_OBJ = test/test1_out_compp.c

DEPS = node_modules

.PHONY: all deps clean distclean check install

all: $(DEPS)
	@../install_coffee_if_not.sh

$(DEPS):
	@echo "Installing required packages..."
	@npm install

clean:
	@rm -f $(TEST_OBJ) $(TEST_COMP_OBJ)

distclean: clean
	@rm -rf $(DEPS)

%_out_cpp.c: %_in.c
	cpp $< -P -o $@

%_out_compp.c: %_in.c $(DRIVER)
	coffee $(DRIVER) $< -o $@

check: all $(TEST_OBJ) $(TEST_COMP_OBJ)
	diff $(TEST_OBJ) $(TEST_COMP_OBJ)

install:
	@echo "error: no install target yet" 1>&2
