0.2.4
=====

Major:
- Addition of PGP for identification, for more information [read the blog post](https://blog.echoplex.us/2014/03/05/echoplexus-and-pgp/)
- Removal of `/identify` and `/register` for identification
- Local rendering of chat messages:  before your messages are even send out to the world, your client will render them locally (with a spinner), replacing them when they echo back to you.  This has the effect of a net increase in speediness, as well as letting you know when your messages aren't delivered in failure situations (never stops spinning)
- Chat and Media Log rendering algorithm changes to ensure that, no matter what, things are inserted in the right order
- More Backbone.Stickit bindings for ChatMessage and MediaLog, allowing us to automatically decrypt the entire chat log after supplying a symmetric key (previously, you had to reload) and allowing us to decrypt all PGP encrypted chat messages as soon as you unlock your PGP keypair
- The 'a few seconds ago', '10 minutes ago' timestamps are now accurate and auto-update every minute
- Tests for various combinations and permutations of symmetric encryption & PGP usage, ensuring messages are routed to who we think they are

Broken:
- Temporarily, preferred timestamps settings will not work

0.2.3
=====

Major:
- Complete rewrite in coffeescript
- Unit tests with `testem`
- Re-tooled and remove `requirejs` in favour of `browserify`
- GitHub postreceive hook support, displaying the commit names & links to the commits
- Firefox Marketplace App that can [be installed here](https://chat.echoplex.us/install.html) or [on the Firefox Marketplace](https://marketplace.firefox.com/app/echoplexus), creating a usable mobile app for Firefox OS, Android via 'Firefox Beta for Android', and desktop clients via Firefox Aurora/Nightly.  If you're a server operator, you can install your own copy by visiting https://yourechoplex.us/install.html
- Mobile styles and touch gesture support
- Automated unit tests via travis
- no longer hear yourself talking when in a call
- fontawesome 4.0.3
- ability to pin the Chat panel in an open state

Minor:
- improved subdivision algorithm of Call panel, proved correctness with unit tests
- miscelaneous other bug fixes uncovered by unit tests
