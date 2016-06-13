require "log4r"

module VagrantPlugins
  module ProviderBhyve
    module Action
      class BootOs

	def initialize(app, env)
	  @logger = Log4r::Logger.new("vagrant_bhyve::action::boot_os")
	  @app = app
	end

	def call(env)
	  machine 	= env[:machine]
	  boot(machine)
	  @app.call(env)
	end

	private

	def boot(machine)
	  driver	= machine.provider.driver
	  driver.bhyve(machine)
	end
      end
    end
  end
end
