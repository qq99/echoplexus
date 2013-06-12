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
