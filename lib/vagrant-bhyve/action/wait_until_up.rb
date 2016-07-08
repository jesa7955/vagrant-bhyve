require "log4r"
require "vagrant/util/retryable"

module VagrantPlugins
  module ProviderBhyve
    module Action
      class WaitUntilUP
        include Vagrant::Util::Retryable

	def initialize(app, env)
	  @logger = Log4r::Logger.new("vagrant_bhyve::action::wait_until_up")
	  @app = app
	end

	def call(env)
	  @driver	= env[:machine].provider.driver
	  env[:ui].info I18n.t('vagrant_bhyve.action.vm.boot.wait_until_up')

         vm_name = @driver.get_attr('vm_name')
         # Check whether ip is assigned
         while !env[:uncleand]
           break if @driver.ip_ready?
           env[:uncleaned] = true if @driver.state(vm_name) == :uncleaned
           sleep 1
         end
         # Check whether we have ssh access
         while !env[:uncleaned]
           break if @driver.ssh_ready?(env[:machine].provider.ssh_info)
           env[:uncleaned] = true if @driver.state(vm_name) == :uncleaned
           sleep 1
         end
	  @app.call(env)
	end

      end
    end
  end
end
