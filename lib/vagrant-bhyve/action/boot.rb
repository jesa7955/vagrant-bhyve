require "log4r"

module VagrantPlugins
  module ProviderBhyve
    module Action
      class Boot

	def initialize(app, env)
	  @logger = Log4r::Logger.new("vagrant_bhyve::action::boot")
	  @app = app
	end

	def call(env)
	  @machine 	= env[:machine]
	  @ui		= env[:ui]
	  @driver	= @machine.provider.driver

          @ui.detail I18n.t('vagrant_bhyve.actions.vm.boot.booting')
	  @driver.boot(@machine)

	  @app.call(env)
	end

      end
    end
  end
end
