# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = '2'

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.

  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.define "frontend" , primary: true do |fe|
    fe.vm.box = 'webhippie/opensuse-13.2'
    # Provision the box with a simple shell script
    fe.vm.provision :shell, path: 'bootstrap.sh'
    fe.vm.provision :shell, inline: 'mount /vagrant/src/api/tmp', run: "always"
    
    # Execute commands in the frontend directory
    fe.exec.commands '*', directory: '/vagrant/src/api'
    fe.exec.commands '*', env: {'DATABASE_URL' => 'mysql2://root:opensuse@localhost/api_development'}
    fe.vm.network :forwarded_port, guest: 3000, host: 3000
  end


  config.vm.define "appliance" , primary: true do |app|
    app.vm.box = 'webhippie/opensuse-13.2'
    # app.exec.commands '*', env: {'RAILS_ENV' => 'production'}
    # app.exec.commands '*', env: {'DATABASE_URL' => 'mysql2://root:opensuse@localhost/api_development'}
    # Provision the box with a simple shell script
    app.vm.provision :shell, path: 'bootstrap-appliance.sh'

    # reboot vm to run obsapisetup
    app.vm.provision :reload


    app.vm.provision :shell, path: 'bootstrap-appliance-finalize.sh'
  end

  # The url from where the 'config.vm.box' box will be fetched if it
  # doesn't already exist on the user's system.
  # config.vm.box_url = "http://domain.com/path/to/above.box"

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.

  config.vm.define "appliance", autostart: false

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  # config.vm.network :private_network, ip: '10.0.2.15', virtualbox__intnet: true

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network :public_network

  # If true, then any SSH connections made will enable agent forwarding.
  # Default value: false
  # config.ssh.forward_agent = true

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"

  # Use 1Gb of RAM for Vagrant box (otherwise bundle will go to swap)
  config.vm.provider :virtualbox do |vb|
    vb.customize ['modifyvm', :id, '--memory', '2048']
    vb.destroy_unused_network_interfaces = true
  end

  config.vm.provider :libvirt do |lv|
      lv.memory = 2048
      # Still having permissions problems with synced_folder 9p but keeping this
      # for documentation purpose
      # config.vm.synced_folder './', '/vagrant', type: '9p', disabled: false
  end

end
