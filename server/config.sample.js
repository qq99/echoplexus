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
		},
		chat: {
			webshot_previews: { // requires phantomjs to be installed
				enabled: true, // http://www.youtube.com/watch?feature=player_detailpage&v=k3-zaTr6OUo#t=23s
				PHANTOMJS_PATH: '/opt/bin/phantomjs',
			},
			rate_limiting: { // slows down spammers
				enabled: true,
				rate: 5.0, // # allowed messages
				per: 8000.0 // per # of seconds
			},
			edit: { // can users edit sent messages?
				enabled: true,
				allow_unidentified: true, // whether anonymous users can edit their messages within the context of the same session
				maximum_time_delta: (1000*60*60*2) // after 2 hours, chat messages will not be editable, delete property to enable indefinitely
			}
		},
		DEBUG: false
	};

})(
  typeof exports === 'object' ? exports : this
);
