echo "=============================="
echo "Set domain"
echo "=============================="

echo -e "Enter Redmine domain / subdomain (i.e. redmine.website.com): \c "
read  DOMAIN

echo -e "Enter Server IP Address (i.e. 192.241.101.90): \c "
read  IP

echo "=============================="
echo "Update sources"
echo "=============================="
read -p "Press any key to continue..."

cat > /etc/apt/sources.list << "EOF"
deb http://ftp.us.debian.org/debian wheezy main
deb http://security.debian.org/ wheezy/updates main
deb http://ftp.us.debian.org/debian unstable main
EOF

apt-get update

echo "=============================="
echo "Install packages"
echo "=============================="
read -p "Press any key to continue..."

aptitude -y install redmine=2.3.1-1 ruby ruby-dev rails rake libtalloc2=2.0.8-0.1 ruby-pg redmine-pgsql=2.3.1-1 ruby-rmagick gem make postgresql-9.1 postgresql-client-9.1 equivs

gem install unicorn

echo "=============================="
echo "Create directories"
echo "=============================="
read -p "Press any key to continue..."

mkdir -p /usr/share/redmine/tmp/sockets 
mkdir /usr/share/redmine/tmp/pids 
mkdir /usr/share/redmine/log 
touch /usr/share/redmine/log/production.log 
cd /usr/share/redmine/config 

echo "=============================="
echo "Write Unicorn config"
echo "=============================="
read -p "Press any key to continue..."

cat > unicorn.rb << "EOF"
#unicorn.rb Starts here 
worker_processes 1 
working_directory "/usr/share/redmine" # needs to be the correct directory for redmine  

# This loads the application in the master process before forking 
# worker processes 
# Read more about it here: 
# http://unicorn.bogomips.org/Unicorn/Configurator.html 
preload_app true
timeout 45  

# This is where we specify the socket. 
# We will point the upstream Nginx module to this socket later on 
listen "/usr/share/redmine/tmp/sockets/unicorn.sock", :backlog => 64 #directory structure needs to be created.  
pid "/usr/share/redmine/tmp/pids/unicorn.pid" # make sure this points to a valid directory.  

# Set the path of the log files inside the log folder of the testapp 
stderr_path "/usr/share/redmine/log/unicorn.stderr.log" 
stdout_path "/usr/share/redmine/log/unicorn.stdout.log"  

before_fork do |server, worker| 
# This option works in together with preload_app true setting 
# What is does is prevent the master process from holding 
# the database connection
defined?(ActiveRecord::Base) and 
ActiveRecord::Base.connection.disconnect! 
end  

after_fork do |server, worker| 
# Here we are establishing the connection after forking worker 
# processes 
defined?(ActiveRecord::Base) and 
ActiveRecord::Base.establish_connection
# change below if your redmine instance is running differently 
worker.user('www-data', 'www-data') if Process.euid == 0 
end 

#unicorn.rb Ends here
EOF

echo "=============================="
echo "Setup Unicorn"
echo "=============================="
read -p "Press any key to continue..."

chown www-data:www-data unicorn.rb 
chown -R www-data:www-data ../tmp 
ln -s /var/lib/gems/1.9.1/bin/unicorn_rails /usr/bin 
cat >> /etc/rc.local << "EOF"
# add this line before exit 0; so it starts on boot. 
unicorn_rails -E production -c /usr/share/redmine/config/unicorn.rb -D
EOF

echo "=============================="
echo "Install Nginx"
echo "=============================="
read -p "Press any key to continue..."

apt-get -y install nginx 
cd /etc/nginx/sites-available 
rm ../sites-enabled/default  

echo "=============================="
echo "Write Nginx config"
echo "=============================="
read -p "Press any key to continue..."

cat > redmine <<EOF
upstream unicorn_server { 
   # This is the socket we configured in unicorn.rb 
   server unix:/usr/share/redmine/tmp/sockets/unicorn.sock 
   fail_timeout=0; 
} 
 
server { 
 
    listen   80; ## listen for ipv4 
 
    server_name $DOMAIN $IP; 
 
    access_log  /var/log/nginx/$DOMAIN.access.log; 
    error_log  /var/log/nginx/$DOMAIN.error.log; 
 
    location / { 
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for; 
      proxy_set_header Host \$http_host; 
      proxy_redirect off;
 
      if (!-f \$request_filename) { 
        proxy_pass http://unicorn_server; 
        break; 
      } 
    } 
}
EOF

echo "=============================="
echo "Set site default"
echo "=============================="
read -p "Press any key to continue..."

ln -s /etc/nginx/sites-available/redmine /etc/nginx/sites-enabled/redmine

echo "=============================="
echo "Fix Rack"
echo "=============================="
read -p "Press any key to continue..."

cd /usr/share/redmine
cat > Gemfile.local << "EOF"
gem "rack", "~> 1.4.5"
EOF

bundle install

cd /usr/bin
equivs-control ruby-rack

cat > ruby-rack << "EOF"
Section: misc
Priority: optional
Standards-Version: 3.9.2

Package: ruby-rack
Version: 1:42
Maintainer: Your Name <your@email.address>
Architecture: all
Description: fake pkgname to block a dumb dependency
EOF

equivs-build ruby-rack
dpkg -i ruby-rack_42_all.deb

echo "=============================="
echo "Start server"
echo "=============================="
read -p "Press any key to continue..."

unicorn_rails -E production -c /usr/share/redmine/config/unicorn.rb -D
/etc/init.d/nginx restart

echo "=============================="
echo "ENJOY!"
echo "=============================="
