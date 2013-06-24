#Installation
So you like the idea of this and want to give it a go? Here's how.
##Dependencies:

### node.js 

For server, confirmed working v0.10.10, and should be OK with v0.10.1*.

    $ git pull https://github.com/joyent/node.git
    $ git checkout v0.10.10
    $ ./configure
    $ make
    $ make install

Known Issues:

- Node v0.10.8 and v0.10.9 have an [incompatibility with socket.io and HTTPS](https://github.com/joyent/node/pull/5624).
- Node v0.11.* has issues with node-sass.

### node.js Packages
Install the required server-side packages

    $ npm install
### bower Packages
Install the required client-side libraries
If you have bower installed globally, you can run:

    $ bower install

Otherwise, please run

    $ npm run-script bower
### Redis

Echoplexus uses Redis for chatlog persistence

    $ sudo apt-get install redis-server

### PhantomJS (optional)

For taking screenshots of websites to embed in the chat.

Download from http://phantomjs.org/

Install the binary to `/opt/bin/phantomjs`

If you don't want to do this step, set "phantomjs_screenshot" to false in `server/config.js`. 
This step also requires cloning the [phantomjs-screenshot](https://github.com/qq99/phantomjs-screenshot) repository beside this repo.

###Building

####Development:

If you have grunt installed globally, you can simply run:

    $ grunt dev

Otherwise you can run:

    $ npm run-script build-dev


####Production:
If you have grunt installed globally, you can simply run:

    $ grunt

Otherwise you can run:

    $ npm run-script build

###Running
Create a copy of the sample config file for the server, and change any relevant options:

    $ cp server/config.sample.js server/config.js


Run `npm start` or just start `server/main.js` with your favorite process manager.  It will become available on http://localhost:8080/ under the default configuration.

If you want to host behind nginx, you will have to get a build with WebSockets enabled.


###Issues
Please report all issues to the github issue tracker.
https://github.com/qq99/echoplexus/issues