# qq99/echoplexus-dev docker file
# A work in progress!
#
# To build this docker image:
# $> sudo docker build -t qq99/echoplexus-dev .
#
# To use this docker image:
# $> sudo docker run -i -v /home/#{YOUR_USERNAME}/echoplexus:/echoplexus:rw -p #{YOUR_PREFERRED_PORTNUMBER}:8080 -t qq99/echoplexus-dev
# From there, you can use tmux to spawn 2 windows and dev (`grunt` in one, `grunt exec` in another)
# or do `grunt build; grunt exec:production` to run a near production mode of echoplexus
FROM ubuntu
RUN apt-get update
RUN apt-get install -y build-essential python ruby git redis-server nodejs phantomjs npm
RUN gem install sass
RUN npm install -g coffee-script grunt grunt-cli supervisor bower testem browserify
RUN ln -sf /usr/bin/nodejs /usr/bin/node
RUN service redis-server start
RUN apt-get install -y tmux
EXPOSE 8080
VOLUME ["/echoplexus"]
ENTRYPOINT ["/usr/bin/tmux"]