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
	  @machine	= env[:machine]
	  @driver	= @machine.provider.driver
	  @ui		= env[:ui]

	  env[:ui].detail I18n.t('vagrant_bhyve.action.vm.boot.create_tap')
	  vm_name	= @driver.get_attr('vm_name')
	  tap_name	= "vagrant_bhyve_#{vm_name}"
	  tap_list 	= [tap_name]
	  # The switch name is used as created bridge device's description
	  tap_list.each do |tap|
	    @driver.create_network_device(tap, "tap", @ui)
	  end
	  @app.call(env)
	end

      end
    end
  end
end
