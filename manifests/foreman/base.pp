class puppet_stack::foreman::base {
  $rvm_prefix          = $::puppet_stack::rvm_prefix
  $ruby_vers           = $::puppet_stack::ruby_vers
  $bundle_path         = "${rvm_prefix}/gems/${ruby_vers}/bin"
  $without_gems        = $::puppet_stack::foreman_db_adapter ? {
    'postgresql' => '--without test sqlite3 mysql2',
    default      => '--without test pg mysql2',
  }
  $bundle_install      = "bundle install ${without_gems} --path vendor"
  $touch_complete      = "echo ${ruby_vers} > vendor/.${ruby_vers}.bundle.install.complete"
  $foreman_user      = $::puppet_stack::foreman_user
  $foreman_user_home = $::puppet_stack::foreman_user_home
  $foreman_repo      = $::puppet_stack::foreman_repo
  $foreman_app_dir   = $::puppet_stack::foreman::foreman_app_dir
  $apache_user       = $::puppet_stack::apache_user

  exec { 'foreman_clone_repo':
    command   => "/usr/bin/git clone ${foreman_repo[url]}",
    user      => $::puppet_stack::foreman_user,
    cwd       => $foreman_user_home,
    logoutput => 'on_failure',
    creates   => $foreman_app_dir,
  }
  
  if has_key($foreman_repo, 'tag') {
    exec { 'foreman_checkout_version':
      command     => "/usr/bin/git checkout -b ${foreman_repo[tag]}-checkout ${foreman_repo[tag]}",
      user        => $::puppet_stack::foreman_user,
      cwd         => $foreman_app_dir,
      logoutput   => 'on_failure',
      refreshonly => true,
      before      => [ File["${foreman_app_dir}/config/settings.yaml", "${foreman_app_dir}/config/database.yml"], Exec['foreman_bundle_install'] ],
      subscribe   => Exec['foreman_clone_repo'],
    }
  }

  file { "${foreman_app_dir}/config/settings.yaml":
    ensure  => 'file',
    owner   => $foreman_user,
    group   => $foreman_user,
    mode    => '0444',
    content => template('puppet_stack/foreman/settings.yaml.erb'),
    notify  => Exec['restart_foreman_app'],
    require => Exec['foreman_clone_repo'],
  }

  file { "${foreman_app_dir}/config/database.yml":
    ensure  => 'file',
    owner   => $foreman_user,
    group   => $foreman_user,
    mode    => '0444',
    content => template('puppet_stack/foreman/database.yml.erb'),
    notify  => Exec['restart_foreman_app'],
    require => Exec['foreman_clone_repo'],
  }

  exec { 'foreman_bundle_install':
    command     => "${rvm_prefix}/bin/rvm ${ruby_vers} do ${bundle_install} && ${touch_complete}",
    user        => $foreman_user,
    environment => [ "HOME=${foreman_user_home}", ],
    cwd         => $foreman_app_dir,
    timeout     => 1800,
    path        => "${bundle_path}:/usr/bin:/bin",
    creates     => "${foreman_app_dir}/vendor/.${ruby_vers}.bundle.install.complete",
  }
}
