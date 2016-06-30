require "log4r"

module VagrantPlugins
  module ProviderBhyve
    module Action
      class Cleanup

	def initialize(app, env)
	  @logger = Log4r::Logger.new("vagrant_bhyve::action::cleanup")
	  @app = app
	end

	def call(env)
	  env[:ui].info I18n.t('vagrant_bhyve.action.vm.halt.cleaning_up')
	  env[:machine].provider.driver.cleanup

	  @app.call(env)
	end

      end
    end
  end
end
