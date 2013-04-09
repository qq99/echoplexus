GEMS=sass
NODE_PACKAGES=express socket.io underscore crypto redis
SASS_FILES=sass/combined.scss sass/main.scss
PUBLIC_DIR=server/public


.PHONY: server install_packages assets css clean

server: server/main.js
	nodemon server/main.js

install_packages:
	npm install $(NODE_PACKAGES) && gem install $(GEMS)

css: $(SASS_FILES)
	mkdir -p $(PUBLIC_DIR)/css 
	sass --style compressed sass/combined.scss:$(PUBLIC_DIR)/css/main.css

clean:
	rm $(PUBLIC_DIR)/css/*.css
