include Makeconf

export HARDWARE

all: pack

skconfig:
	$(MAKE) $@ -C tools

skpacker: policy
	$(MAKE) $@ -C tools

skpolicy:
	$(MAKE) $@ -C tools

policy: skpolicy
	$(MAKE) -C $@

subjects: skconfig policy
	$(MAKE) -C $@

kernel: policy
	$(MAKE) -C $@

pack: skpacker kernel subjects
	$(MAKE) -C $@

deploy: HARDWARE=t430s
deploy: pack
	$(MAKE) -C $@

emulate: pack
	$(MAKE) -C $@

clean:
	$(MAKE) clean -C deploy
	$(MAKE) clean -C tools
	$(MAKE) clean -C kernel
	$(MAKE) clean -C pack
	$(MAKE) clean -C policy
	$(MAKE) clean -C subjects

.PHONY: deploy emulate kernel pack policy subjects
