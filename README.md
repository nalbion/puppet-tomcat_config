# Tomcat Config

Can be used in a similar way to apache::vhost to create multiple instances of Tomcat listening on different ports.
Based on [Advanced Configuration - Multiple Tomcat Instances](http://tomcat.apache.org/tomcat-7.0-doc/RUNNING.txt)

On Linux machines an init.d script is created for each instance.  The script supports `start`, `stop`, `restart` and `status`.


## Usage
```puppet
# Configure the standard instance to listen on port 8080
tomcat_config::instance { 'tomcat-pub':
    http_port => '80',
}

# Create a second instance. listening on port 8081
tomcat_config::instance { 'tomcat1':
    http_port     => '8081',
    shutdown_port => '8005',
    ajp_port      => '8009',
    redirect_port => '8843',
    # Create a 'setenv.sh'/'setenv.bat' file to add 
    # `-Dspring.profiles.active=<%= @environment %>' to JAVA_OPTS
    support_spring_profiles => true,
}

# Install another instance, but disable it
tomcat_config::instance { 'tomcat2':
    http_port     => '8082',
    shutdown_port => '8006',
    ajp_port      => '8010',
    redirect_port => '8844',
    enable        => false,
}
```