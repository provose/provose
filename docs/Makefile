clean:
	rm -rfv _site .jekyll-cache .mypy_cache
	find . -name '*.tfstate*' -delete
	find . -name '.terraform' -exec rm -rfv {} \;
	terraform fmt -recursive