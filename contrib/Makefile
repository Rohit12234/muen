RECIPES =    \
	ada-bfd  \
	alog     \
	gnatcoll \
	lsc      \
	xia

ifdef QUIET
VERBOSE = @
endif

all: build_recipes

build_recipes:
	$(VERBOSE)$(foreach recipe,$(RECIPES),$(MAKE) -C $(recipe) || exit 1;)

download:
	$(VERBOSE)$(foreach recipe,$(RECIPES),$(MAKE) -C $(recipe) download || exit 1;)

clean:
	$(VERBOSE)$(foreach recipe,$(RECIPES),$(MAKE) -C $(recipe) clean;)
	$(VERBOSE)rm -rf build
