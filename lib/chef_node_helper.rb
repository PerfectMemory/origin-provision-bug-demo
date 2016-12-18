# Wrapper to populate the extensive chef.json attributes dynamically from config

module ChefNodeHelper
  def self.setup_chef_environment!(chef)
    chef.environments_path, chef.environment = File.split('environments/dev')
    chef.custom_config_path = 'lib/vagrant-chef-solo.rb'
    #chef.data_bags_path = 'data_bags'
    chef.roles_path = 'roles'
    # share nodes_path (should enable chef search(), as long as every node
    # explicitly saves themself properly at the end of their chef_run).
    chef.nodes_path = 'nodes' # shared between all instances for search() to work.
    # hack: chef bucket somehow not cached if /var/chef does not exist on boot;
    # as a workaround we move the chef file_cache_path to the cache bucket.
    # TODO: report as bug on https://github.com/fgrehm/vagrant-cachier/issues
    if Vagrant.has_plugin?('vagrant-cachier')
      chef.file_cache_path = '/tmp/vagrant-cache/chef'
    end
  end
end
