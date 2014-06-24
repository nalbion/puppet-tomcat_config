# To be used with boxupp-tomcat and tomcat_config::instance
class tomcat_config (
  $owner         = hiera('tomcat::tomcat_owner', 'tomcat'),
  $group         = hiera('tomcat::tomcat_group', 'tomcat'),
) {
  
  $catalina_home = "${::tomcat::tomcat_path}/${::tomcat::tomcat_version}"
    
  file { $catalina_home:
    ensure  => present,
    owner   => $owner,
    group   => $group,
    recurse => true
  }
  
  file { "${catalina_home}/conf":
    ensure  => directory,
    mode    => '0644',
    recurse => true,
  }
}