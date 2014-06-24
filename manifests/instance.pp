# Can be used in a similar way to apache::vhost to create multiple instances of Tomcat
# listening on different ports
# == Example:
#  tomcat_config::instance { 'tomcat-pub':
#    http_port => '80'
#  }
define tomcat_config::instance (
  $service_name  = '',
  $init_script   = '',
  $http_port     = '8080',
  $shutdown_port = '8005',
  $ajp_port      = '8009',
  $redirect_port = '8843',
  $owner         = hiera('tomcat::tomcat_owner', 'tomcat'),
  $group         = hiera('tomcat::tomcat_group', 'tomcat'),
  $java_version  = hiera('tomcat::java_version', '7' ),
  $java_dir      = hiera('tomcat::java_dir',     '/usr/java' ),
  $enable        = true,
  $support_spring_profiles = true,
) {
  $real_service_name = $service_name ? {
    ''      => $name,
    default => $service_name,
  }
  $real_init_script = $init_script ? {
    ''      => $real_service_name,
    default => $init_script,
  }
  $ensure = $enable ? {
    true => running,
    false => stopped,
  }
    
  $suffix = $::operatingsystem ? {   # or osfamily 
    windows => '.bat',
    default => '.sh',
  }
  
  $catalina_home = "${::tomcat::tomcat_path}/${::tomcat::tomcat_version}"

  case $java_version {
    '8': {
      $java_home = "${java_dir}/jdk1.8.0"
    }
    '7': {
      $java_home = "${java_dir}/jdk1.7.0"
    }
    default: {
      fail("Unsupported java_version: ${java_version}.  Implement me?")
    }
  }
  
  include tomcat_config

  if( $real_service_name == 'tomcat' ) {
    # Default instance, but with customised ports
    $catalina_base = $catalina_home
  } else {
    # http://tomcat.apache.org/tomcat-7.0-doc/RUNNING.txt - Advanced Configuration - Multiple Tomcat Instances
    $catalina_base = "${::tomcat::tomcat_path}/${real_service_name}"
    
    file { "${catalina_base}/bin/tomcat-juli.jar":
      ensure  => present,
      source  => "${catalina_home}/bin/tomcat-juli.jar",
      require => File[$catalina_home],
      before  => Service[$real_service_name],
    }
    file { "${catalina_base}/conf":
      ensure  => present,
      source  => "${catalina_home}/conf",
      owner   => $owner,
      group   => $group,
      mode    => '0644',
      recurse => true,
      ignore  => "server.xml",
      require => File[$catalina_home],
      before  => Service[$real_service_name],
    }
    file { "${catalina_base}/lib":
      ensure  => present,
      source  => "${catalina_home}/lib",
      recurse => true,
      require => File[$catalina_home],
      before  => Service[$real_service_name],
    }
    file { [ "${catalina_base}/bin", "${catalina_base}/logs", "${catalina_base}/temp", 
             "${catalina_base}/webapps", "${catalina_base}/work" ]:
      ensure  => directory,
      require => File[$catalina_base],
      before  => Service[$real_service_name],
    }
    
    # $catalina_home and $catalina_home/conf are managed in the init.pp script
    file { $catalina_base:
      ensure  => directory,
      owner   => $owner,
      group   => $group,
      recurse => true,
    }
        
    $copy = $::kernel ? {
      windows => 'copy',
      default => 'cp',
    }
  
    # This can't be managed as a File resource because otherwise it always replaces the 
    # edits made by Augeas, so Augeas then reapplies the changes and restarts Tomcat
    exec { "Copy ${catalina_base}/conf/server.xml":
      command => "${copy} ${catalina_home}/conf/server.xml ${catalina_base}/conf/server.xml",
      creates => "${catalina_base}/conf/server.xml",
      require => File["${catalina_base}/conf"],
      before  => Augeas["${catalina_base}/conf/server.xml"],
    }
  }
    
  augeas { "${catalina_base}/conf/server.xml":
    lens    => 'Xml.lns',
    incl    => "${catalina_base}/conf/server.xml",
    context => "/files${catalina_base}/conf/server.xml",
    changes => [
      "set Server/#attribute/port $shutdown_port",
      "set Server/Service/Connector[#attribute/protocol=~regexp('http/?1.?1','i')]/#attribute/port $http_port",
      "set Server/Service/Connector[#attribute/protocol=~regexp('AJP.*')]/#attribute/port $ajp_port",
      "set Server/Service/Connector[1]/#attribute/redirectPort $redirect_port",
      "set Server/Service/Connector[2]/#attribute/redirectPort $redirect_port",
    ],
    before  => Service[$real_service_name],
    notify  => Service[$real_service_name],
  }
  
  # The Augeas & Exec tasks will copy the file over, but perhaps with the wrong owner & group
  file { "${catalina_base}/conf/server.xml":
    ensure  => present,
    owner   => $owner,
    group   => $group,
    require => Augeas["${catalina_base}/conf/server.xml"],
  }
  
    
  if ( $support_spring_profiles ) {
    # Configure Tomcat to use the appropriate environment
    file { "${catalina_base}/bin/setenv${suffix}":
      ensure  => present,
      content => template("tomcat_config/setenv${suffix}.erb"),
      require => File[$catalina_base],
      before => Service[$real_service_name],
    }
  }
  
  case $::kernel {
    Linux: {
      # Custom init.d script which supports 'status' and multiple tomcat instances 
      file { "/etc/init.d/$real_init_script":
        ensure  => present,
        content => template('tomcat_config/init.d'),
        mode    => '0755',
        before  => Service[$real_service_name],
      }
    }
#    Windows: {
#      Create service:
#      sc create $real_service_name binpath=""
#      or
#      # http://tomcat.apache.org/tomcat-7.0-doc/windows-service-howto.html
#      service.bat install $real_service_name
#      or
#      # http://tomcat.apache.org/tomcat-7.0-doc/windows-service-howto.html
#      tomcat7 //IS//Tomcat7 --DisplayName="Apache Tomcat 7" \
#        --Install="C:\Program Files\Tomcat\bin\tomcat7.exe" --Jvm=auto \
#        --StartMode=jvm --StopMode=jvm \
#        --StartClass=org.apache.catalina.startup.Bootstrap --StartParams=start \
#        --StopClass=org.apache.catalina.startup.Bootstrap --StopParams=stop
#      # Update:
#      tomcat7 //US//MyService --Description="Apache Tomcat Server - http://tomcat.apache.org/ " \
#        --Startup=auto --Classpath=%JAVA_HOME%\lib\tools.jar;%CATALINA_HOME%\bin\bootstrap.jar
#    }
    default: {
      notice("Tomcat as a service is not currently supported by tomcat_config::instance for ${::kernel}.  Implement me? (Windows should be fairly simple)")
    }
  }
  
  # Make sure Tomcat is running (unless disabled) 
  service { $real_service_name:
      ensure     => $ensure,
      hasrestart => true,
  }
}