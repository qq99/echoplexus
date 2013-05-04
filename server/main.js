var express = require('express'),
	_ = require('underscore'),
	Backbone = require('backbone'),
	crypto = require('crypto'),
	fs = require('fs'),
	redis = require('redis'),
	sio = require('socket.io'),
	app = express(),
	redisC = redis.createClient(),
	server = require('http').createServer(app),
	spawn = require('child_process').spawn,
	async = require('async'),
	chatServer = require('./ChatServer.js').ChatServer,
	codeServer = require('./CodeServer.js').CodeServer,
	PUBLIC_FOLDER = __dirname + '/public',
	SANDBOXED_FOLDER = PUBLIC_FOLDER + '/sandbox';

var config = require('./config.js').Configuration;


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
	res.sendfile("server/public/index.html");
});
server.listen(config.host.PORT);

console.log('Listening on port', config.host.PORT);

// SocketIO init:
sio = sio.listen(server);
sio.enable('browser client minification');
sio.enable('browser client gzip');
sio.set('log level', 1);

chatServer(sio, redisC); // start up the chat server
codeServer(sio, redisC); // start up the code server