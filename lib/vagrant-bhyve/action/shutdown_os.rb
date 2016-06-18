require "log4r"

module VagrantPlugins
  module ProviderBhyve
    module Action
      class ShutdownOS

	def initialize(app, env)
	  @logger = Log4r::Logger.new("vagrant_bhyve::action::shutdown_os")
	  @app = app
	end

	def call(env)
	  @machine 	= env[:machine]
	  @driver	= machine.provider.driver
	  @driver.shutdown(env)
	  @app.call(env)
	end

      end
    end
  end
end
