EMACS ?= emacs
LINT_ELPA := $(CURDIR)/.elpa

.PHONY: test compile lint check-web

test:
	$(EMACS) -Q --batch \
		--eval "(progn (require 'package) (package-initialize))" \
		-L . -L test \
		-l bufferline-test \
		-f ert-run-tests-batch-and-exit

compile:
	$(EMACS) -Q --batch \
		--eval "(progn (require 'package) (package-initialize))" \
		--eval "(setq byte-compile-error-on-warn t)" \
		-L . \
		-f batch-byte-compile bufferline*.el; \
	status=$$?; rm -f *.elc; exit $$status

lint:
	$(EMACS) -Q --batch \
		--eval "(require 'package)" \
		--eval "(setq package-user-dir \"$(LINT_ELPA)\")" \
		--eval "(add-to-list 'package-archives '(\"melpa\" . \"https://melpa.org/packages/\"))" \
		--eval "(package-initialize)" \
		--eval "(unless (package-installed-p 'package-lint) (package-refresh-contents) (package-install 'package-lint))" \
		--eval "(setq package-lint-main-file \"bufferline.el\")" \
		-f package-lint-batch-and-exit bufferline*.el

check-web:
	node --check web/app.js
