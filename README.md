[echoplexus](https://echoplex.us) (v0.1.4)
==================

Dive in! [chat.echoplex.us](https://chat.echoplex.us "https://chat.echoplex.us")

Join the developer chat @ [chat.echoplex.us/echodev](https://chat.echoplex.us/echodev "Echoplexus Developer Chat")

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
- `/join [channel_name]`: Join a channel
- `/nick [your_nickname]`: Changes your name from Anonymous; this preference is stored in a cookie on a per channel basis
- `/register [some_password]`: Facilitates linkable anonymity; people talking to you yesterday can rest assured you're the same person today (and not an impersonator trying to steal your nickname) by registering and identifying.
- `/identify [your_password]`: Assume command of your nickname, and get a green checkmark beside it notifying others that you are identified.
- `/private [channel_password]`: Makes a channel private.  Only those with the password may enter it.
- `/password [channel_password]`: Join a private channel.
- `/public`: Make the private channel a public channel.
- `/whisper [nickname]`: Send a private message that is visible to anybody with the nickname you've supplied.  Aliases: `/w`, `/tell`, `/t`, `/pm`.  *Pro-tip:* Press "ctrl+r" to quick-reply to the last person who has whispered you -- it'll append `/w [nick]` to your current chat buffer.
- `/pull [N]`: Sync the N latest chat messages that you've missed while you weren't connected to the channel.  Currently, maximum is set to 100 for UI responsiveness until a more efficient rendering method is added.
- `[partial nickname]+<TABKEY>`: Autocompletes (based on L-Distance) to the name of somebody in the channel
- `/color [#FFFFFF]`: Supply a 6-digit hex code with or without the `#`, and change your nickname's color
- `/edit #[integer] [new body text]`: Changes the body text of a specific message to something else.  Useful for correcting typos and censoring yourself.  Only usable for messages you've posted while identified as the user that sent the chat message.  Also usable any time within the same browser session if not identified (e.g., Anonymous users can edit their own chats until they disconnect).

Nickname registrations are considered on a per-channel basis to increase the available nickspace for all users.

Some measures of User Access Controls are planned for the future.

Code
----

Currently, interactive and collaborative HTML & JavaScript is supported, with evaluation taking place after a user stops typing.  The code is run in a fully sandboxed iframe without access to cookies or anything of the sort.  By default, the iframe has access to jQuery and underscore.js for user convenience.  The REPL is only evaluated if you have the JavaScript tab open.  Future support for more languages is planned.

Draw
----

Right now, the Draw capabilities are pretty basic; just enough to facilitate sharing a persistent whiteboard with the people you're chatting with.  There is *much* room for improvement here but I do not think that there is a need to re-invent the wheel and re-implement Photoshop/Illustrator here.

Security
--------

*echoplexus is not secure, but it's getting there.*  Your registration, 
identification, and private channel passwords are first salted with 256 random 
bytes from node's `crypto.randomBytes`.  Then, they are run through 4096 
iterations of `crypto.pbkdf2` with a key length of 256 bytes before the is 
stored in Redis.  Of course, this is meaningless since there isn't HTTPS by 
default (for that, I apologize).  I'd especially appreciate any input in 
securing echoplexus.  You should rest assured that this project will take 
security very seriously.  *Currently, the chatlogs of a private channel are not
encrypted!*

It is recommended to setup a non-privileged user for `echoplexus` and run `node.js` 
as this user on a non-privileged port (default is `8080`).

    $ adduser --disabled-login --gecos 'Sandbox' $SANDBOX_USERNAME
    $ cd /home/$SANDBOX_USERNAME
    $ sudo -u $SANDBOX_USERNAME git clone git://github.com/qq99/echoplexus.git
    ...continue similarly to the steps below, prefixing 'sudo -u $SANDBOX_USERNAME' if appropriate ...

From there, you may do one of the following, depending on your needs:

1. Pro: Proxy echoplexus behind nginx v1.3.13 or later (requires WebSocket 
   support). You may also use HAProxy.
2. Git'r done: Update iptables to redirect port 80 or 443 to the port of your 
   choice. *Remember to save and test your rules!*

Example:

    $ iptables  -t nat -I PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8080


License:
-------
GPLv3 and MIT
