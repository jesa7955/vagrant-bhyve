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
	  @ui		= env[:ui]
	  @driver	= @machine.provider.driver
	  
          @ui.info I18n.t('vagrant.actions.vm.boot.booting')
	  @ui.detail I18n.t('vagrant_bhyve.action.vm.boot.setup_nat')

	  switch_list 	= %w(vagrant_bhyve_default_switch)
	  # The switch name is used as created bridge device's description
	  switch_list.each do |switch|
	    @driver.create_network_device(switch, "bridge")
	    @driver.enable_nat(switch, @ui)
	  end
	  @app.call(env)
	end

      end
    end
  end
end
