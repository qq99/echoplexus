echoplexus (v0.10)
==================

[http://echoplex.us](http://echoplex.us "overview landing page")
Dive in: [chat.echoplex.us](http://chat.echoplex.us/github "chat.echoplex.us /github channel")

What is it?
-----------

echoplexus was designed to be a modular, anonymous, real-time chatting system.  I believe it works ideally for teams that want to host a copy of echoplexus locally, and also for groups of friends who care about their data.  The name echoplexus was mostly motivated by the song, "Echoplex" by Nine Inch Nails.  Listen to it and you might get a feel for how I felt while testing this ;)

Currently, echoplexus is composed of 3 components: Chat, Code, and Draw.  Each has it's own section of server code such that you could conceivably run any combination (or just 1) of these modules, depending on your needs.

Motivation
----------

To understand why I think a project like this is valuable, I think you should understand my motivation:

I was fed up with IRC -- it's somewhat time consuming to set up a server, people don't want to set up a client, they don't want to configure servers and ports in their client.  If you do end up accomplishing the former, you're still stuck with a text-only interface for the majority of the participants.  Your IP is also visible to others unless you go through work to hide it.  Google Talk is OK, but by default, it's a 1v1 chat with limited capabilities for media embedding.  Hangouts might worry you about it's lack of federation.  echoplexus makes no claims of federation -- mainly because I do not see how that would work.

I love anonymity, so by default there is no account set-up required to begin chatting.

Chat
----

The most important part of echoplexus is the support for anonymity.  Users hate sign-ups.  Anonymity fosters freedom of speech.  Linkable anonymity is also possible (if you know IRC, think nickserv's identify/register).

echoplexus will attempt to embed any image URLs directly into the Media bar on the right side.  This is a user configurable setting that is on by default.  Similarly, it will attempt to parse YouTube URLs and embed an object directly in the chat.  If the server settings are enabled to do so, echoplexus will also attempt to take a screenshot and a short excerpt of any non-media URL linked in the chat to provide a quick preview/overview to chat participants.

Currently Supported Commands:
- /join [channel_name]: Join a channel
- /nick [your_nickname]: Changes your name from Anonymous; this preference is stored in a cookie on a per channel basis
- /register [some_password]: Facilitates linkable anonymity; people talking to you yesterday can rest assured you're the same person today (and not an impersonator trying to steal your nickname) by registering and identifying.
- /identify [your_password]: Assume command of your nickname, and get a green checkmark beside it notifying others that you are identified.
- /private [channel_password]: Makes a channel private.  Only those with the password may enter it.
- /password [channel_password]: Join a private channel.
- /public: Make the private channel a public channel.

Nick name registrations are considered on a per-channel basis to increase the available nickspace for all users.

Some measures of User Access Controls are planned for the future.

Code
----

Currently, interactive and collaborative HTML & JavaScript is supported, with evaluation taking place after a user stops typing.  The code is run in a sandboxed `iframe`, but I'd appreciate any audits to this functionality as it makes me nervous.  By default, the `iframe` has access to jQuery and underscore.js for user convenience.  The REPL is only evaluated if you've got the JavaScript tab open.  Ideally, more languages will be supported.

Security
--------

*echoplexus is not secure, but it's getting there.*  Your registration, identification, and private channel passwords are first salted with 256 random bytes from node's `crypto.randomBytes`.  Then, they are run through 4096 iterations of `crypto.pbkdf2` with a key length of 256 bytes before the is stored in redis.  Of course, this is meaningless since there isn't HTTPS by default (for that, I apologize).  I'd especially appreciate any input in securing echoplexus.  You should rest assured that this project will take security very seriously.  *Currently, the chatlogs of a private channel are not encrypted!*

The phantomjs_screenshotting is currently accomplished by starting as the rooter user, then immediately dropping privileges to another sandboxed user (named sandbox) who hopefully should be more limited under an attack.  This really makes me nervous.

If you're using it on a relatively private server or on a LAN, you should have little worries.

Draw
----

Right now, the Draw capabilities are pretty basic; just enough to facilitate sharing a persistent whiteboard with the people you're chatting with.  There's a lot of deficiencies in this part of the code.  There is *much* room for improvement here but I don't know that we need to re-invent the wheel and re-implement Photoshop/Illustrator here.

Developing echoplexus
=================

So you like the idea of this and want to give it a go.  Here's how:

Dependencies:
-------------
- *node.js*: for server, confirmed working v.10.9, and should be OK with v.10.* -- node-sass has troubles with v.11.*-pre

> git pull https://github.com/joyent/node.git

> ./configure

> make

> make install

- *phantomjs* (optional): for taking screenshots of websites to embed in the chat
Download from http://phantomjs.org/
Install the binary to /opt/bin/phantomjs

If you don't want to do this step, set "phantomjs_screenshot" to false in server/config.js
This step also requires cloning the [phantomjs-screenshot](https://github.com/qq99/phantomjs-screenshot) repository beside this repo.

- *redis*: for persistence
> sudo apt-get install redis-server

- *node packages*
> npm install

Building:
---------

`npm run-script build`


Running the server:
-------------------

Create a copy of the sample config file for the server, and change any relevant options:
> cp server/config.sample.js server/config.js

Run `npm start` or `nodemon server/main.js` or `node server/main.js`.  It will become available on http://localhost:8080/ under the default configuration.

If you want to host with nginx, you're going to have to get a build with WebSockets enabled.

License:
-------
GPLv3 and MIT
