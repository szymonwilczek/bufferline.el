EMACS ?= emacs

.PHONY: test check-web

test:
	$(EMACS) -Q --batch \
		--eval "(progn (require 'package) (package-initialize))" \
		-L . -L test \
		-l bufferline-test \
		-f ert-run-tests-batch-and-exit

check-web:
	node --check web/app.js
