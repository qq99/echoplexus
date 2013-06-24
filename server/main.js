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
	path = require('path'),
	EventBus = new Backbone.Model(),
	chatServer = require('./ChatServer.js').ChatServer,
	codeServer = require('./CodeServer.js').CodeServer,
	drawServer = require('./DrawingServer.js').DrawingServer,
	ROOT_FOLDER = path.dirname(__dirname),
	PUBLIC_FOLDER = ROOT_FOLDER + '/public',
	SANDBOXED_FOLDER = PUBLIC_FOLDER + '/sandbox',
	CLIENT_FOLDER = ROOT_FOLDER + '/client';

var protocol = require(config.host.SCHEME);

if (config.host.SCHEME === 'https') {
	var privateKey  = fs.readFileSync(config.ssl.PRIVATE_KEY).toString();
	var certificate = fs.readFileSync(config.ssl.CERTIFICATE).toString();
	var credentials = { key: privateKey, cert: certificate };
	var server = protocol.createServer(credentials, app); 
} else {
	var server = protocol.createServer(app);
}
var index = "public/index.dev.html";
if(fs.existsSync(PUBLIC_FOLDER+'/index.build.html'))
	index = "public/index.build.html";
console.log('Using index: ' + index);
// Custom objects:
// shared with the client:
var Client = require('../client/client.js').ClientModel,
	Clients = require('../client/client.js').ClientsCollection,
	REGEXES = require('../client/regex.js').REGEXES;

// Web server init:

app.use('/client',express.static(CLIENT_FOLDER));

app.use(express.static(PUBLIC_FOLDER));
// always server up the index
// 
app.use('/',function(req,res){
	res.sendfile(index);
});
app.get("/*", function (req, res) {
	res.sendfile(index);
});
server.listen(config.host.PORT);

console.log('Listening on port', config.host.PORT);

// SocketIO init:
sio = sio.listen(server);
sio.enable('browser client minification');
sio.enable('browser client gzip');
sio.set('log level', 1);

// use db 15:
redisC.select(15, function (err, reply) {
	var ChannelStructures = require('./Channels.js').ChannelStructures(redisC, EventBus),
		Channels = new ChannelStructures.ChannelsCollection(),
		ChannelModel = ChannelStructures.ServerChannelModel;

	chatServer(sio, redisC, EventBus, Channels, ChannelModel); // start up the chat server
	codeServer(sio, redisC, EventBus, Channels); // start up the code server
	drawServer(sio, redisC, EventBus, Channels); // start up the code server
});
