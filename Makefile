OUT = compp.js

COFFEE_OBJ = compp.js ConcatBackslashNewlinesStream.js analyzeLines.js

TEST_OBJ = test/test1_out_cpp.c
TEST_COMP_OBJ = test/test1_out_compp.c

DEPS = node_modules

COFFEE_FLAGS =

.PHONY: all deps clean distclean check install

%.js: %.coffee
	coffee -o . -c $(COFFEE_FLAGS) $<

%_out_cpp.c: %_in.c
	cpp $< -P -o $@

%_out_compp.c: %_in.c $(OUT)
	node $(OUT) $< -o $@

all: $(COFFEE_OBJ) $(DEPS)

$(DEPS):
	npm install

clean:
	@rm -f $(COFFEE_OBJ)
	@rm -f $(TEST_OBJ)

distclean: clean
	@rm -rf $(DEPS)

check: $(TEST_OBJ) $(TEST_COMP_OBJ)
	diff $(TEST_OBJ) $(TEST_COMP_OBJ)

install:
	@echo "error: no install target yet" 1>&2
