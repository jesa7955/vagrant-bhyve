require "log4r"
require "securerandom"

module VagrantPlugins
  module ProviderBhyve
    module Action
      class Import

	def initialize(app, env)
	  @logger = Log4r::Logger.new("vagrant_bhyve::action::import")
	  @app = app
	end

	def call(env)
	  @machine 	= env[:machine]
	  @driver	= @machine.provider.driver
	  @ui		= env[:ui]

	  @ui.info I18n.t("vagrant.action.vm.clone.creating")
          @machine.id 	= SecureRandom.uuid
	  @driver.import(@machine.id)
	  @app.call(env)
	end

      end
    end
  end
end
