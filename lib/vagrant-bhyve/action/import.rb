require "log4r"
require "securerandom"
require "digest/md5"

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

          @machine.id 	= SecureRandom.uuid
	  @driver.import(@machine)
	  @app.call(env)
	end

      end
    end
  end
end
