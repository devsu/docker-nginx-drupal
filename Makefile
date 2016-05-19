CURRENT_DIRECTORY := $(shell pwd)

build:
	@docker build --tag=devsu/nginx-drupal7 $(CURRENT_DIRECTORY)

build-no-cache:
	@docker build --no-cache --tag=devsu/nginx-drupal7 $(CURRENT_DIRECTORY)

.PHONY: build

