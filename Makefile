# http://stackoverflow.com/questions/14028268/proper-method-for-wildcard-targets-in-gnu-make
# generated shell script
DRIVER = compp
DRIVER_JS = $(patsubst %, obj/%.js, $(DRIVER))

# put source inputs in src/ and make them coffee files
SRC = $(wildcard src/*.coffee)
# make will output .js in obj/ as .js files
OBJ = $(patsubst src/%.coffee, obj/%.js, $(SRC))

# put test inputs in test/ and name them something that matches /test.+_in.c/
TEST_IN = $(wildcard test/test*_in.c)
# output of tests will be in test/ and match /test.+_out_(cpp|compp).c/
# these are the output of cpp
TEST_OBJ = $(patsubst test/test%_in.c, test/test%_out_cpp.c, $(TEST_IN))
# these are the output of compp!
TEST_COMPP_OBJ = $(patsubst test/test%_in.c, test/test%_out_compp.c, $(TEST_IN))

DEPS = node_modules

.PHONY: all clean distclean check install

all: $(DEPS) $(OBJ)

# install_coffee_if_not.sh runs every time a .coffee file is compiled
# the alternative is to run it in $(DEPS) and there's no guarantee make will
# compile $(DEPS) before $(OBJ)
# the below compiles all of $(OBJ)
obj/%.js: src/%.coffee
	@../install_coffee_if_not.sh
	coffee -o obj -bc $<

# no space between node and $(DRIVER_JS) for aesthetic reasons; the space is
# actually inserted in the generated file
$(DRIVER):
	@echo "#!/bin/sh" > $@
	@echo "# generated driver script" >> $@
	@echo "WD=\$$(cd \"\$$(dirname \"\$${BASH_SOURCE[0]}\")\" && pwd)" >> $@
	@echo "cd \"\$$WD\"" >> $@
	@echo >> $@
	@echo "# pass all arguments to compp as args to node process" >> $@
	@echo "node$(DRIVER_JS) \$$@" >> $@
	@chmod +x $@

$(DEPS):
	@echo "Installing required packages..."
	@npm install

clean:
	@rm -f $(OBJ) $(TEST_OBJ) $(TEST_COMP_OBJ)

distclean: clean
	@rm -rf $(DEPS)

# let's make those tests
%_out_cpp.c: %_in.c
	cpp $< -P -o $@

%_out_compp.c: %_in.c $(DRIVER)
	./$(DRIVER) $< -o $@

# we rely here on the test input/output naming scheme described above
check: all $(TEST_OBJ) $(TEST_COMPP_OBJ)
	@./run_tests.sh $(TEST_OBJ)

install:
	@echo "error: no install target yet" 1>&2
