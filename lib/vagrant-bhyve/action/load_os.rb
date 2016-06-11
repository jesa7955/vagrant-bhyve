require "log4r"

module VagrantPlugins
  module ProviderBhyve
    module Action
      class LoadKernelModule

	def initialize(app, env)
	  @logger = Log4r::Logger.new("vagrant_bhyve::action::load_os")
	  @app = app
	end

	def call(env)
	  machine 	= env[:machine]
	  load(machine)
	  @app.call(env)
	end

	private

	def load(machine)
	  driver	= machine.provider.driver
	  firmware	= machine.box.metadata[:firmware]
	  loader	= machine.box.metadata[:loader]
	  driver.load(loader, machine) if firmware == 'bios'
	end
      end
    end
  end
end
