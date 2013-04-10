Developing yasioc
=================

Dependencies:
-------------
	- node: for server

	> git pull https://github.com/joyent/node.git
	> ./configure
	> make
	> make install


	- redis: for persistence

	> sudo apt-get install redis-server


	- ruby: for sass
	I'm using 2.0.0 installed via RVM, but it shouldn't matter much

	- node packages and ruby gems: in the top level of the repo,

	> make install_packages

Running:
--------

Run `make server` or `nodemon server/main.js`
