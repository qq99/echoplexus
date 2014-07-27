#Installation

So you like the idea of this and want to give it a go? Here's how.

###Security (optional):

It is recommended to setup a non-privileged user for `echoplexus` and run `node.js`
as this user on a non-privileged port (default is `8080`).

    $ adduser --disabled-login --gecos 'Sandbox' $SANDBOX_USERNAME
    $ cd /home/$SANDBOX_USERNAME
    $ sudo -u $SANDBOX_USERNAME git clone git://github.com/qq99/echoplexus.git
    ...continue similarly to the steps below, prefixing 'sudo -u $SANDBOX_USERNAME' if appropriate ...

From there, you may do one of the following, depending on your needs:



##Dependencies:

### node.js
Confirmed working nodejs is v0.10.25.  You might have luck with your current node, so perhaps try that before you do the following:

### node.js Packages
Install the required server-side packages

    $ npm install
    $ npm install -g coffee-script grunt grunt-cli supervisor bower browserify testem (probably need `sudo`)

### bower Packages
Install the required client-side libraries
If you have bower installed globally (the previous step), you can run:

    $ bower install
    
### Ruby

Any version will do.  `gem install sass`

### Redis

Echoplexus uses Redis for chatlog persistence

    $ sudo apt-get install redis-server

### PhantomJS (optional)

For taking screenshots of websites to embed in the chat.

Recent ubuntus can install it via:

    $ sudo apt-get install phantomjs

Otherwise, download from http://phantomjs.org/.  Install the binary to `/usr/bin/phantomjs`.

If you don't want to do this step, set "phantomjs_screenshot" to false in `server/config.js`.

###Building

####Development:

If you have grunt installed globally, you can simply run:

    $ grunt

This will create all the files you need to run echoplexus, but will leave CSS and JS unminified.

####Production:
If you have grunt installed globally, you can simply run:

    $ grunt build

###Running
Create a copy of the sample config file for the server, and change any relevant options:

    $ cp src/server/config.sample.coffee src/server/config.coffee

Run `grunt exec` for a dev server, or `grunt exec:production` for a production server.  The former will stop on errors and restart immediately when a file changes.  The latter will wait 60s before restarting.  The server will become available on http://localhost:8080/ under the default configuration.

If you want to host behind nginx, you will have to get a build with WebSockets enabled.  Recommended version of nginx is 1.5.0 or higher

###Web Server Proxying:

You have at least two options in exposing your deployment.  We recommend:

1. Pro: Proxy echoplexus behind nginx v1.3.13 or later (requires WebSocket
   support). We've attached a [sample configuration](https://github.com/qq99/echoplexus/blob/0.2.3/src/server/samples/echoplexus.site "Sample Echoplexus nginx configuration"). You may also use HAProxy.
2. Git'r done: Update iptables to redirect port 80 or 443 to the port of your
   choice. *Remember to save and test your rules!*

Example:

    $ iptables  -t nat -I PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8080

###Issues
Please report all issues to the github issue tracker.
https://github.com/qq99/echoplexus/issues


***********
# On Amazon EC2, for echoplexus@0.2.2

c/o user @dirkk0

`sudo apt-get update`

### get ec2 ip and hostname
`curl http://xxx.xxx.xxx.xxx/latest/meta-data/public-ipv4 > public.ip`
`curl http://xxx.xxx.xxx.xxx/latest/meta-data/public-hostname > public.hostname`

`sudo apt-get install --yes build-essential curl git`

### install latest node
```
sudo apt-get install --yes python-software-properties python g++ make
sudo add-apt-repository --yes ppa:chris-lea/node.js
sudo apt-get update
sudo apt-get install --yes nodejs
```
### install redis
`sudo apt-get install -y redis-server`
### clone echoplexus
`git clone https://github.com/qq99/echoplexus`
### build echoplexus
```
cd echoplexus
npm install; npm run-script bower; sudo npm install -g grunt-cli
npm run-script build; grunt; cp server/config.sample.js server/config.js
sed -e "s/chat.echoplex.us/`cat public.hostname`/g" echoplexus/server/config.js > temp && mv temp echoplexus/server/config.js
cd ..
```
`screen -S server -L -m`
