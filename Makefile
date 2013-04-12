GEMS=sass
NODE_PACKAGES=express socket.io underscore crypto redis nodemon
SASS_FILES=sass/combined.scss sass/main.scss sass/monokai.scss
PUBLIC_DIR=server/public
BUILD_DIR=build

#  !! order is important in the client libs !!
LIBS=client/lib/underscore-min.js client/lib/jquery.min.js client/lib/jquery.cookie.js client/lib/moment.min.js client/lib/codemirror-3.11/lib/codemirror.js client/lib/codemirror-3.11/mode/javascript/javascript.js
CLIENT_JS=client/client.js client/ui.js


.PHONY: server install_packages assets css clean client_js

server: server/main.js
	nodemon server/main.js

install_packages:
	npm install $(NODE_PACKAGES) && gem install $(GEMS)

create_build_dir:
	mkdir -p $(BUILD_DIR)

client_libs: create_build_dir
	cat $(LIBS) > $(BUILD_DIR)/libs.js
	uglifyjs $(BUILD_DIR)/libs.js > $(BUILD_DIR)/libs.min.js
	cp $(BUILD_DIR)/libs.min.js $(PUBLIC_DIR)/libs.min.js

client_js: create_build_dir
	cat $(CLIENT_JS) > $(BUILD_DIR)/yasioc.js
	uglifyjs $(BUILD_DIR)/yasioc.js > $(BUILD_DIR)/yasioc.min.js
	cp $(BUILD_DIR)/yasioc.min.js $(PUBLIC_DIR)/yasioc.min.js

css: $(SASS_FILES)
	mkdir -p $(PUBLIC_DIR)/css 
	sass --style compressed sass/combined.scss:$(PUBLIC_DIR)/css/main.css

client: client_libs client_js css

clean:
	rm $(PUBLIC_DIR)/css/*.css
	rm -rf $(BUILD_DIR)