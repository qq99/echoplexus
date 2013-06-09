var config = require('./config.js').Configuration;

var express = require('express'),
	_ = require('underscore'),
	Backbone = require('backbone'),
	crypto = require('crypto'),
	fs = require('fs'),
	redis = require('redis'),
	sio = require('socket.io'),
	app = express(),
	redisC = redis.createClient(),
	spawn = require('child_process').spawn,
	async = require('async'),
	chatServer = require('./ChatServer.js').ChatServer,
	codeServer = require('./CodeServer.js').CodeServer,
	drawServer = require('./DrawingServer.js').DrawingServer,
	PUBLIC_FOLDER = __dirname + '/../public',
	SANDBOXED_FOLDER = PUBLIC_FOLDER + '/sandbox';

var protocol = require(config.host.SCHEME);

if (config.host.SCHEME == 'https') {
	var privateKey  = fs.readFileSync(config.ssl.PRIVATE_KEY).toString();
	var certificate = fs.readFileSync(config.ssl.CERTIFICATE).toString();
	var credentials = { key: privateKey, cert: certificate };
	var server = protocol.createServer(credentials, app); 
} else {
	var server = protocol.createServer(app);
}

// Custom objects:
// shared with the client:
var Client = require('../client/client.js').ClientModel,
	Clients = require('../client/client.js').ClientsCollection,
	REGEXES = require('../client/regex.js').REGEXES;

// special things to do on init:
if (config.features.phantomjs_screenshot) { // change the user of the current process
	process.setgid('sandbox');
	process.setuid('sandbox');
	console.log('Now leaving the DANGERZONE!', 'New User ID:', process.getuid(), 'New Group ID:', process.getgid());
	console.log('Probably still a somewhat dangerous zone, tho.');
}

// Web server init:
app.use(express.static(PUBLIC_FOLDER));
// always server up the index.html
app.get("/*", function (req, res) {
	res.sendfile("public/index.html");
});
server.listen(config.host.PORT);

console.log('Listening on port', config.host.PORT);

var EventBus = new Backbone.Model();

// SocketIO init:
sio = sio.listen(server);
sio.enable('browser client minification');
sio.enable('browser client gzip');
sio.set('log level', 1);

// use db 15:
redisC.select(15, function (err, reply) {
	chatServer(sio, redisC, EventBus); // start up the chat server
	codeServer(sio, redisC, EventBus); // start up the code server
	drawServer(sio, redisC, EventBus); // start up the code server
});
