var express = require('express'),
	fs = require('fs'),
	jade = require('jade'),
	sio = require('socket.io'),
	app = express(),
	server = require('http').createServer(app),
	PORT = 8999;


// Standard App:
app.use(express.static(__dirname + '/public'));
app.get("/views/chat", function (req, res) {

});

server.listen(PORT);
console.log('Listening on port', PORT);


var SERVER = "SYSTEM";

// regexes:
var NICK = /^\/nick/;

// SocketIO:
sio = sio.listen(server);

sio.sockets.on('connection', function (socket) {
	socket.set('nick', "Anonymous");

	socket.emit('chat', {
		nickname: SERVER,
		body: 'Welcome to a new experimental chat.  Try sending an image URL.  Test: http://i.imgur.com/Qpkx6FJh.jpg',
		type: "SYSTEM"
	});
	socket.broadcast.emit('chat', {
		body: 'Somebody has joined the chat.'
	});
	socket.on('chat', function (data) {
		if (data.body) {
			if (data.body.match(NICK)) {
				var newName = data.body.replace(NICK, "").trim();
				socket.get('nick', function (err, prevName) {
					socket.set('nick', newName);
					socket.broadcast.emit('chat', {
						body: prevName + " is now known as " + newName
					});
					socket.emit('chat', {
						body: "You are now known as " + newName
					});
				});

			} else {
				socket.get('nick', function (err, name) {
					data.nickname = name;
					socket.broadcast.emit('chat', data);
					socket.emit('chat', data);
				});
			}
		}  	
	});
	socket.on('disconnect', function () {
		socket.get('nick', function (err, name) {
			socket.broadcast.emit('chat', {
				body: name + ' has left the chat.'
			});
		});
	})
});