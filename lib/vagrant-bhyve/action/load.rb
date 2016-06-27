require "log4r"

module VagrantPlugins
  module ProviderBhyve
    module Action
      class Load

	def initialize(app, env)
	  @logger = Log4r::Logger.new("vagrant_bhyve::action::load")
	  @app = app
	end

	def call(env)
	  @machine 	= env[:machine]
	  @driver	= @machine.provider.driver
	  firmware	= @machine.box.metadata['firmware']
	  loader	= @machine.box.metadata['loader']

          env[:ui].info I18n.t('vagrant_bhyve.action.vm.boot.load_kernel')
	  @driver.load(loader, @machine, @ui) if firmware == 'bios'

	  @app.call(env)
	end
	
      end
    end
  end
end
