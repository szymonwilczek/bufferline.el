EMACS ?= emacs

.PHONY: test

test:
	$(EMACS) -Q --batch \
		--eval "(progn (require 'package) (package-initialize))" \
		-L . -L test \
		-l bufferline-test \
		-f ert-run-tests-batch-and-exit
