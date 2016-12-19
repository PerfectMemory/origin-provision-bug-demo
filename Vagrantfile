# -*- mode: ruby -*-
# vi: set ft=ruby :

# Load defaults from .env, if present
Dotenv.load!('.env') if defined?(Dotenv)

# DRY this into constants because we need these in multiple places.
INTERNAL_NETWORK = '192.168.33.0/24'.freeze # all nodes should be included in this network!
MASTER_NODES = [
  { 'ipaddress' => '192.168.33.220', 'fqdn' => 'master', 'labels' => 'region=infra' }
].freeze
MINION_NODES = (1..Integer(ENV.fetch('MINIONS', 1))).map do |i|
  { 'ipaddress' => format('192.168.33.%d', 220 + i), 'fqdn' => format('node-%d', i), 'labels' => 'region=primary' }
end.freeze

ENV['VAGRANT_DEFAULT_PROVIDER'] = 'virtualbox'

# Import some helpers
require_relative 'lib/chef_node_helper'

Vagrant.configure(2) do |config|
  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box      = 'opscode_centos-7.2_chef-provisionerless'
  config.vm.box_url  = 'http://opscode-vm-bento.s3.amazonaws.com/vagrant/virtualbox/opscode_centos-7.2_chef-provisionerless.box'

  # forward ssh agent so that we can 'git clone' in some cookbooks.
  config.ssh.forward_agent = true

  if Vagrant.has_plugin?('vagrant-cachier')
    # Configure cached packages to be shared between instances of the same base box.
    # More info on http://fgrehm.viewdocs.io/vagrant-cachier/usage
    config.cache.scope = :box
  end

  # Workaround issue https://github.com/tmatilai/vagrant-proxyconf/pull/93
  # This requires vagrant-proxyconf >= 1.5.0, so please upgrade your plugin!
  if Vagrant.has_plugin?('vagrant-proxyconf')
    config.proxy.enabled = { docker: false }
  end

  # Use recent chef version (we used to provision with chef11 but chef12 is the way to go).
  if Vagrant.has_plugin?('vagrant-omnibus')
    config.omnibus.chef_version = '12.17.44'
  end

  # Provisionning. All cookbooks must have been previously declared in `Berksfile`.
  config.berkshelf.enabled = true

  # Fix issues with Virtualbox DNS proxy when changing network on the host
  # http://serverfault.com/questions/453185/vagrant-virtualbox-dns-10-0-2-3-not-working
  config.vm.provider :virtualbox do |vb|
    vb.customize ['modifyvm', :id, '--natdnshostresolver1', 'on']
  end

  # The openshift master VMs
  MASTER_NODES.each do |spec|
    config.vm.define spec['fqdn'], primary: true do |master|
      master.vm.hostname = spec['fqdn']
      master.vm.network 'private_network', ip: spec['ipaddress']
      master.vm.provider 'virtualbox' do |vb|
        vb.memory = 2560
        vb.cpus = 3
      end

      # workaround for https://github.com/mitchellh/vagrant/issues/5590, which still applies in 2016 :)
      master.vm.provision 'shell', inline: 'nmcli connection reload; systemctl restart network.service'
      master.vm.provision 'chef_solo' do |chef|
        ChefNodeHelper.setup_chef_environment!(chef)
        chef.json['cookbook-openshift3'] = {
          'master_servers' => MASTER_NODES,
          'node_servers' => MINION_NODES + MASTER_NODES, # master runs 'region=infra' node
          'openshift_common_public_hostname' => "#{spec['ipaddress']}.xip.io",
          'openshift_master_router_subdomain' => "cloudapps.#{spec['ipaddress']}.xip.io",
          'openshift_master_logging_public_url' => "kibana.cloudapps.#{spec['ipaddress']}.xip.io",
          'openshift_master_metrics_public_url' => "hawkular-metrics.#{spec['ipaddress']}.xip.io",
          'openshift_common_default_nodeSelector' => "region=#{MINION_NODES.empty? ? 'infra' : 'primary'}",
          'openshift_common_ip' => spec['ipaddress']
        }
        chef.add_role 'openshift3-base'
      end
    end
  end

  # The openshift minion VMs
  MINION_NODES.each do |spec|
    config.vm.define spec['fqdn'], primary: false do |minion|
      minion.vm.hostname = spec['fqdn']
      minion.vm.network 'private_network', ip: spec['ipaddress']
      minion.vm.provider 'virtualbox' do |vb|
        vb.memory = 3072 - 512 * [MINION_NODES.length, 3].min
        vb.cpus = 2
      end

      # workaround for https://github.com/mitchellh/vagrant/issues/5590, which still applies in 2016 :)
      minion.vm.provision 'shell', inline: 'nmcli connection reload; systemctl restart network.service'
      minion.vm.provision 'chef_solo' do |chef|
        ChefNodeHelper.setup_chef_environment!(chef)
        chef.json['cookbook-openshift3'] = {
          'master_servers' => MASTER_NODES,
          'node_servers' => MINION_NODES + MASTER_NODES, # master runs 'region=infra' node
          'openshift_common_ip' => spec['ipaddress']
        }
        chef.add_role 'openshift3-base'
      end
    end
  end
end
