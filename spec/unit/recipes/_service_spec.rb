require 'spec_helper'

describe_recipe 'consul::_service' do
  it do
    expect(chef_run).to create_directory('/var/lib/consul')
      .with(mode: 0755)
    expect(chef_run).to create_directory('/etc/consul.d')
      .with(mode: 0755)
  end

  context 'with default attributes' do
    it { expect(chef_run).not_to include_recipe('runit::default') }
    it { expect(chef_run).not_to create_user('consul service user: root') }
    it { expect(chef_run).not_to create_group('consul service group: root') }
    it do
      expect(chef_run).to create_file('/etc/consul.d/default.json')
        .with(user: 'root')
        .with(group: 'root')
        .with(mode: 0600)
    end
    it do
      expect(chef_run).to create_template('/etc/init.d/consul')
        .with(source: 'consul-init.erb')
        .with(mode: 0755)
    end
    it do
      expect(chef_run).to enable_service('consul')
        .with(supports: {status: true, restart: true, reload: true})
      expect(chef_run).to start_service('consul')
    end
  end

  context 'config on centos' do
    let(:chef_run) do
      ChefSpec::Runner.new(platform: 'centos', version: '6.3').converge(described_recipe)
    end
    it do
      expect(chef_run).to create_template('/etc/sysconfig/consul')
        .with(source: 'consul-sysconfig.erb')
        .with(mode: 0755)
    end
    it do
      expect(chef_run).to render_file('/etc/sysconfig/consul').with_content('GOMAXPROCS=1')
    end
  end

  context 'config on ubuntu' do
    let(:chef_run) do
      ChefSpec::Runner.new(platform: 'ubuntu', version: '14.04').converge(described_recipe)
    end
    it do
      expect(chef_run).to create_template('/etc/default/consul')
        .with(source: 'consul-sysconfig.erb')
        .with(mode: 0755)
    end
    it do
      expect(chef_run).to render_file('/etc/default/consul').with_content('GOMAXPROCS=1')
    end
  end

  context %Q(with node['consul']['init_style'] = 'runit') do
    let(:chef_run) do
      ChefSpec::Runner.new(node_attributes) do |node|
        node.set['consul']['init_style'] = 'runit'
      end.converge(described_recipe)
    end

    it { expect(chef_run).to include_recipe('runit::default') }
    it do
      expect(chef_run).to create_directory('/etc/consul.d')
        .with(mode: 0755)
      expect(chef_run).to create_directory('/var/log/consul')
        .with(mode: 0755)
    end
    it do
      expect(chef_run).to create_user('consul service user: consul')
        .with(shell: '/bin/false')
        .with(username: 'consul')
        .with(home: '/dev/null')
    end
    it do
      expect(chef_run).to create_group('consul service group: consul')
        .with(group_name: 'consul')
        .with(members: ['consul'])
        .with(append: true)
    end
    it do
      expect(chef_run).to create_file('/etc/consul.d/default.json')
        .with(user: 'consul')
        .with(group: 'consul')
        .with(mode: 0600)
    end
    it do
      expect(chef_run).to enable_runit_service('consul')
        .with(supports: {status: true, restart: true, reload: true})
        .with(options: {consul_binary: '/usr/local/bin/consul', config_dir: '/etc/consul.d'})
      expect(chef_run).to start_runit_service('consul')
    end
  end

  context 'with a cluster service_mode, bootstrap_expect > 1, and a server list to join' do
    let(:chef_run) do
      ChefSpec::Runner.new(node_attributes) do |node|
        node.set['consul']['service_mode'] = 'cluster'
        node.set['consul']['bootstrap_expect'] = '3'
        node.set['consul']['servers'] = [ 'server1', 'server2', 'server3' ]
      end.converge(described_recipe)
    end
    it do
      expect(chef_run).to create_file('/etc/consul.d/default.json')
        .with_content(/start_join/)
        .with_content(/server1/)
        .with_content(/server2/)
        .with_content(/server3/)
    end
  end

  context 'with a cluster service_mode, bootstrap_expect = 1, and a server list' do
    let(:chef_run) do
      ChefSpec::Runner.new(node_attributes) do |node|
        node.set['consul']['service_mode'] = 'cluster'
        node.set['consul']['bootstrap_expect'] = '1'
        node.set['consul']['servers'] = [ 'server1', 'server2', 'server3' ]
      end.converge(described_recipe)
    end
    it do
      expect(chef_run).to_not create_file('/etc/consul.d/default.json')
        .with_content(/start_join/)
        .with_content(/server1/)
        .with_content(/server2/)
        .with_content(/server3/)
    end
  end

  context 'with extra params' do
    let(:chef_run) do
      ChefSpec::Runner.new(node_attributes) do |node|
        node.set['consul']['extra_params']['disable_remote_exec'] = true 
      end.converge(described_recipe)
    end
    it do
      expect(chef_run).to_not create_file('/etc/consul.d/default.json')
        .with_content(/"disable_remote_exec" : "true"/)
    end
  end


end
