require "log4r"

module VagrantPlugins
  module ProviderBhyve
    module Action
      class CreateBridge

	def initialize(app, env)
	  @logger = Log4r::Logger.new("vagrant_bhyve::action::create_bridge")
	  @app = app
	end

	def call(env)
	  @machine 	= env[:machine]
	  @ui		= env[:ui]
	  @driver	= @machine.provider.driver
	  
          @ui.info I18n.t('vagrant.actions.vm.boot.booting')
	  @ui.detail I18n.t('vagrant_bhyve.action.vm.boot.setup_nat')

	  bridge_list 	= %w(vagrant_bhyve_default_bridge)
	  # The bridge name is used as created bridge device's description
	  bridge_list.each do |bridge|
	    @driver.create_network_device(bridge, "bridge", @ui)
	    @driver.enable_nat(bridge, @ui)
	  end
	  @app.call(env)
	end

      end
    end
  end
end
