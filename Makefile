.PHONY: lint test verify

lint:
	./Scripts/lint.sh

test:
	./Scripts/test.sh

verify:
	$(MAKE) lint
	$(MAKE) test
