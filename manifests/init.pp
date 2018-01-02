class windows_manages_symlinks_failure {
  case $::osfamily {
    'Windows': {
      $link = 'C:/Windows/Temp/foo'
      $target = 'C:/Windows/Temp/bar'
    }
    default: {}
  }

  file { $target:
    ensure => 'directory',
    mode   =>  '0755',
  }

  file { $link:
    ensure  => 'link',
    target  => $target,
    require => File[$target],
  }
}
