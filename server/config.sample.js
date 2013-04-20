(function( exports ) {
	
	// customize me:
	exports.Configuration = {
		host: {
			SCHEME: "http",
			FQDN: "chat.echoplex.us",
			PORT: 8080,
			USE_PORT_IN_URL: true,
		},
		features: {
			SERVER_NICK: 'Server',
			phantomjs_screenshot: true, // http://www.youtube.com/watch?feature=player_detailpage&v=k3-zaTr6OUo#t=23s
		}
	};

})(
  typeof exports === 'object' ? exports : this
);