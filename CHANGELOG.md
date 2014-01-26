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

Minor:
- improved subdivision algorithm of Call panel, proved correctness with unit tests
- miscelaneous other bug fixes uncovered by unit tests
