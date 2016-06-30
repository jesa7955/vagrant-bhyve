require "log4r"

module VagrantPlugins
  module ProviderBhyve
    module Action
      class Destroy

	def initialize(app, env)
	  @logger = Log4r::Logger.new("vagrant_bhyve::action::destroy")
	  @app = app
	end

	def call(env)
	  env[:ui].info I18n.t('vagrant_bhyve.action.vm.destroying')
	  env[:machine].provider.driver.destroy

	  @app.call(env)
	end

      end
    end
  end
end
