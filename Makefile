BIN = ./node_modules/.bin

release-patch:
	@$(call release,patch)

release-minor:
	@$(call release,minor)

release-major:
	@$(call release,major)

build:
	@$(BIN)/coffee -c -o dist src/index.coffee
	@$(BIN)/webpack

publish:
	git push --tags origin HEAD:master
	@$(BIN)/coffee -c -o dist src/index.coffee
	npm publish

publish-gh-pages:
	git checkout gh-pages
	git merge master
	@$(BIN)/webpack --config webpack.production.config.js
	cp examples/* .
	git add --all .
	git commit -m "New release"
	git push origin gh-pages
	git checkout master

define release
	npm version $(1)
endef
