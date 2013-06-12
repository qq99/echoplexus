(function( exports ) {
	
	// customize me:
	exports.Configuration = {
		host: {
			SCHEME: "http",
			FQDN: "chat.echoplex.us",
			PORT: 8080,
			USE_PORT_IN_URL: true,
		},
		ssl: {
			USE_NODE_SSL: false, // must be true if you want SSL & you don't have another SSL web server proxying to the echoplexus server
			PRIVATE_KEY: '/path/to/server.key',
			CERTIFICATE: '/path/to/certificate.crt'
		},
		features: {
			SERVER_NICK: 'Server',
			PHANTOMJS_SCREENSHOT: false, // http://www.youtube.com/watch?feature=player_detailpage&v=k3-zaTr6OUo#t=23s
			PHANTOMJS_PATH: '/opt/bin/phantomjs'
		},
		DEBUG: false
	};

})(
  typeof exports === 'object' ? exports : this
);
