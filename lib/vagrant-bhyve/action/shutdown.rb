require "log4r"

module VagrantPlugins
  module ProviderBhyve
    module Action
      class Shutdown

	def initialize(app, env)
	  @logger = Log4r::Logger.new("vagrant_bhyve::action::shutdown")
	  @app = app
	end

	def call(env)
	  @machine 	= env[:machine]
	  @ui		= env[:ui]
	  @driver	= @machine.provider.driver

	  @ui.info('vagrant_bhyve.vm.action.halt.shutting_down')
	  @driver.shutdown(@ui)
	  @app.call(env)
	end

      end
    end
  end
end
