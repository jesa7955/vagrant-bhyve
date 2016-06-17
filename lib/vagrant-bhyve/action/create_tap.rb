require "log4r"

module VagrantPlugins
  module ProviderBhyve
    module Action
      class CreateTap

	def initialize(app, env)
	  @logger = Log4r::Logger.new("vagrant_bhyve::action::create_tap")
	  @app = app
	end

	def call(env)
	  @machine 	= env[:machine]
	  @driver	= @machine.provider.driver
	  tap_name	= "vagrant_bhyve_" + machine.box.name.gsub('/', '_')
	  tap_list 	= [tap_name]
	  # The switch name is used as created bridge device's description
	  for tap in tap_list
	    interface_name = @driver.create_network_device(tap, "tap", env)
	    @machine.env[:tap] = interface_name
	  end
	  @app.call(env)
	end

      end
    end
  end
end
