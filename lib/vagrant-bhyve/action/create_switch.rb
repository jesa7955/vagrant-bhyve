require "log4r"

module VagrantPlugins
  module ProviderBhyve
    module Action
      class CreateSwitch

	def initialize(app, env)
	  @logger = Log4r::Logger.new("vagrant_bhyve::action::create_switch")
	  @app = app
	end

	def call(env)
	  @machine 	= env[:machine]
	  @driver	= @machine.provider.driver
	  switch_list 	= %w(vagrant_bhyve_default_switch)
	  directory = @machine.box.directory
	  ui = @machine.ui
	  # The switch name is used as created bridge device's description
	  for switch in switch_list
	    bridge_name = @driver.create_network_device(switch, "bridge")
	    @driver.enable_nat(switch, directory, ui)
	    machine.env[:switch] = bridge_name
	  end
	  @app.call(env)
	end

      end
    end
  end
end
