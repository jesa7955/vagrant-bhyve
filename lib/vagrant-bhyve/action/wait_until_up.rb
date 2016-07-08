require "log4r"

module VagrantPlugins
  module ProviderBhyve
    module Action
      class WaitUntilUP

	def initialize(app, env)
	  @logger = Log4r::Logger.new("vagrant_bhyve::action::wait_for_ip")
	  @app = app
	end

	def call(env)
	  @driver	= env[:machine].provider.driver
	  env[:ui].info I18n.t('vagrant_bhyve.action.vm.boot.wait_for_ip')
      @driver.wait_for_ip
	  @app.call(env)
	end

      end
    end
  end
end
