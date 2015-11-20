consul_install node[:install_method] do
  version '0.5.2'
  binary_url "https://dl.bintray.com/mitchellh/consul/%{filename}.zip"
  source_url node[:consul_source] || ''
  action node[:consul_install_action] || :install
end
