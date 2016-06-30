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

	  env[:ui].info I18n.t('vagrant_bhyve.action.vm.import_box')
          @machine.id 	= SecureRandom.uuid
	  id		= @machine.id.split(/-/)[-1] 
	  vm_name	= "#{@machine.box.name.gsub('/', '_')}_#{id}"
	  @driver.store_attr('vm_name', vm_name)
	  @driver.import(@machine, env[:ui])
	  @app.call(env)
	end

      end
    end
  end
end
