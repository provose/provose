help:
	@echo "Help:"
	@echo "\tmake clean: Clean the compiled site and Terraform state"
	@echo "\tmake fmt: Format the Terraform code"

clean:
	rm -rfv _site .jekyll-cache .mypy_cache
	find . -name '*.tfstate*' -delete
	find . -name '.terraform' -exec rm -rfv {} \;

fmt:
	terraform fmt -recursive

.PHONY: help clean fmt