[echoplexus](https://echoplex.us) (v0.2.3)
==================

[![Stories in Ready](https://badge.waffle.io/qq99/echoplexus.png)](http://waffle.io/qq99/echoplexus)
[![Build Status](https://img.shields.io/travis/qq99/echoplexus.svg)](https://travis-ci.org/qq99/echoplexus)

Dive in! [chat.echoplex.us](https://chat.echoplex.us "https://chat.echoplex.us")

[Parlez-vous français? Continuez ici](https://github.com/tetalab/echoplexus/)

Join the developer chat @ [chat.echoplex.us/echodev](https://chat.echoplex.us/echodev "Echoplexus Developer Chat")

[What's new?](https://github.com/qq99/echoplexus/blob/master/CHANGELOG.md "Echoplexus Changelog")

In a nutshell
-------------

Echoplexus is an anonymous, web-based, IRC-like chatting platform that makes its best effort to respect your privacy.  It allows you to create public or private channels.  You can secure a pseudonym for linkable anonymity (think: `/msg nickserv register ____`.  You can code and draw together in real time.  **As of v0.2.0, you can make Peer2Peer video and voice calls with the people in your channel.**

Future Goals
------------

- Peer2Peer file transfer via WebRTC
- Peer2Peer chat, boostrapped by Echoplexus (to facilitate off-the-record communication)
- End2End encryption
- Increased selection of languages for the real-time collaborative REPL

Be sure to check out the planned [enhancements](https://github.com/qq99/echoplexus/issues?labels=enhancement&milestone=&page=1&state=open "Planned Enhancements")

What is it?
-----------

echoplexus was designed to be a modular.  It started from a simple chatting base application and has really grown to encompass many different things.

Currently, echoplexus is composed of 4 modules: Chat, Code, Draw, and Call.  Conceivably, you could run any combination (or just 1) of these modules, depending on your needs.

Why would I want this?
----------------------

Echoplexus works well for teams that want to enable rich, secure, and truly privacy respecting chat.  Since it's OSS and fairly easy to install, you can have your own private communication infrastructure without needing to rely on cloud services.  There's peace of mind in that.  We've found it's also great for groups of friends who care about their data (and who may or may not be looking at it).

Many teams might use a pay-to-use web-based communication platform.  There are many out there, and we've derived some inspiration from them in our development.  Echoplexus bridges that gap with open source software.

Others use IRC.  However, it's somewhat time consuming to set up a server, many people don't really want to set up a client, and they certainly don't want to configure servers and ports in their client.  In the end, most of the users are stuck with a text-only interface (no rich media).  Your IP is also visible to others unless you go through measures to hide it.

Other services (like Google Talk / Hangouts) are OK, but by default they are 1v1 chat, a closed client platform, and cloud-based.

Almost all of the alternatives require you to specifiy some kind of name before you start chatting.  Worse, register with an e-mail address.  I always thought the biggest barrier was requiring the user to perform actions he doesn't care about completing -- he's got many other things to do!  Anonymity can be conducive to great conversations.

Chat
----

The most important part of echoplexus is the support for anonymity.  Users hate sign-ups.  Anonymity fosters freedom of speech.  Linkable anonymity is also possible.

echoplexus will attempt to embed any image URLs directly into the Media bar on the right side.  Similarly, it will attempt to parse YouTube URLs and embed an object.  When the server encounters a URL, it can take a screenshot of the page in question along and attempt to provide a short excerpt to the user.  To protect your privacy, media embedding is disabled for the client by default.

You can edit any message you've sent up to 2 hours ago, as long as you haven't lost your connection.  This duration is configurable by server operators.  You can edit across connections (regardless of time elapsed) if you were identified when you sent the message.  You can do this by double clicking the message, or clicking the pencil icon that appears while hovering the message.

When you join a channel, you'll automatically sync some of the most recent chat history you may have missed while you were away.  At any time, you can pull the chatlog history for that channel.  Messages sent by identified users will have a green lock icon while hovering the chat message, allowing you to protect your identity throughout history.

Currently Supported Commands:
- `/join [channel_name]`: Join a channel
- `/leave`: Leaves the current channel
- `/topic [topic string]`: Set the topic of conversation for the channel (the message that sits visible at all times at the top)
- `/broadcast [a chat message]`: Send the message to every channels that you're connected to.  Alias: `/bc`
- `/nick [your_nickname]`: Changes your name from Anonymous; this preference is stored in a cookie on a per channel basis
- `/register [some_password]`: Facilitates linkable anonymity; people talking to you yesterday can rest assured you're the same person today (and not an impersonator trying to steal your nickname) by registering and identifying.
- `/identify [your_password]`: Assume command of your nickname, and get a green lock icon beside it (signifying to others that you are identified).
- `/private [channel_password]`: Makes a channel private.  Only those with the password may enter it.
- `/public`: Make the private channel a public channel.
- `/whisper [nickname]`: Send a private message that is visible to anybody with the nickname you've supplied.  Aliases: `/w`, `/tell`, `/t`, `/pm`.  *Pro-tip:* Press "ctrl+r" to quick-reply to the last person who has whispered you.
- `/pull [N]`: Sync the N latest chat messages that you've missed while you weren't connected to the channel.  Currently, maximum is set to 100 for UI responsiveness until a more efficient rendering method is added.
- `[partial nickname]+<TABKEY>`: Autocompletes (based on L-Distance) to the name of somebody in the channel
- `@[nickname]`: Gets the attention of the user in question
- `/color [#FFFFFF]`: Supply a 6-digit hex code with or without the `#`, and change your nickname's color
- `/edit #[integer] [new body text]`: Changes the body text of a specific message to something else.  Useful for correcting typos and censoring yourself.  You can also double click on a chat message to edit inline-- press enter to confirm, escape or click elsewhere to cancel.
- `>>[integer]`: Quotes a specific chat message.  Clicking the Reply icon on the chat message will automatically add this for you.
- `/chown [password]`: Become the channel owner.  This gives you all permissions in the channel and allows you to `/chmod`
- `/chmod [(+|-)permissionName] [optional username]`:  This allows you to selectively toggle on/off certain permissions for the particular channel or user.  User permissions are checked first, and if not set, then channel permissions are checked.  If a username is not supplied, then the permission is specified at the channel level.
- `/github track [github repo URL]`: This generates a URL that you can add to your repo's postreceive hooks on Github.
- `/roll [1d20|2d30|5d6] )`: will roll a 1d20.  When rolling multiples, each roll is displayed then added together.  Trying to roll an invalid dice format will default to a d20.
Aliases: `/r`
- `/destroy`: If you are the channel owner, you can delete the entire chatlog history for the channel in question.  There is no recovery!

Example:
  - `/chmod -canSpeak`: now everyone in the channel can't speak unless you do `/chmod +canSpeak [username]` to selectively enable it for a specific user.

The currently implemented list of permissions (and their defaults) includes:
  - canSetTopic: null
  - canMakePrivate: null
  - canMakePublic: null
  - canSpeak: true
  - canPullLogs: true
  - canUploadFile: null
  - canSetGithubPostReceiveHooks: null

*Note:* Nickname registrations are considered on a per-channel basis to increase the available nickspace for all users.  Thus, you will have to register for a specific nickname many times across each channel you join.

Server-hosted file upload
-------------------------

You can upload a file by dragging it onto the "Media & Links" panel.  From there, you'll have the option of confirming the upload, as well as an image preview (if it is an image).

For server operators, this must be enabled in `config.js` (see `config.sample.js`).  You have the option of setting a max file size limit.  Further, it must be enabled on a per-channel basis by the channel operator.  If there is not yet a channel operator, you will need to `/chown [operator password]` to become it (see `Commands` above).

Code
----

Currently, interactive and collaborative HTML & JavaScript is supported.  A sandboxed `iframe` is used to protect the contents of your browser, but just to be completely safe, no code is evaluated without your consent.  A `LiveReload` checkbox allows you to re-evaluate as you or someone else types.  A `Refresh` button resets & wipes the `iframe` state.

The `iframe` has access to `jQuery` and `underscore.js` for user convenience.  More libraries may be exposed in the future.

Draw
----

Right now, the Draw capabilities are fairly basic; just enough to facilitate sharing a persistent whiteboard with the people you're chatting with.  I do not think that there is a need to completely re-invent the wheel (and end up re-implementing Photoshop/Illustrator here).

Call
----

Make a secure Peer2Peer audio & video call with everyone in the same channel as you, using WebRTC.  For this, you'll probably want to use Chrome Canary/Beta or Firefox Aurora/Beta, which, at the time of writing, have experimental WebRTC support.

Security
--------

*echoplexus is not completely secure, but it's getting there.*  You should rest assured that this project will take security very seriously.

### Registration / Identification / Private Channels

Your registration, identification, and private channel passwords are first salted with 256 random bytes from node's `crypto.randomBytes`.  Then, they are run through 4096 iterations of `crypto.pbkdf2` with a key length of 256 bytes before the is stored in Redis.  In your deployment, these measures can be considered meaningless if you do not use HTTPS.

### Encryption

You'll notice the `Not Encrypted` button on the chat input area when you first join a channel.  When you click this button, you'll have the option of providing a shared secret (*you should negotiate this through a secure side channel, not on echoplexus*).  Once supplied, the button will change to `Encrypted`.  Encryption is performed with the `Crypto-JS` library (256-bit AES).

Things that are currently encrypted:
  - Nickname
  - Chat messages
  - Private messages

Everything else is transmitted in plaintext at the moment.

Specific things that will not work as a result:
  - Permissions set on a specific user (since the server doesn't know their nickname)
  - PhantomJS webshot previews (since the server can't read the body text to screenshot the URL)
  - Identity (since the server doesn't know your nickname)

With encryption, not even the 
