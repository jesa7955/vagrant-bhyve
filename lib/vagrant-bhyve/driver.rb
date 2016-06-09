require "vagrant/util/subprocess"
require "log4r"

module VagrantPlugins
  module ProviderBhyve
    class Driver

      # This executor is responsible for actually executing commands, including 
      # bhyve, dnsmasq and other shell utils used to get VM's state
      attr_accessor :executor
      
      @@sudo = ''

      def initialize(machine)
	@logger = Log4r::Logger.new("vagrant::bhyve::driver")
	@machine = machine
	@executor = Executor::Exec.new
      end

      # if vagrant is excecuted by root (or with sudo) then the variable
      # will be empty string, otherwise it will be 'sudo' to make sure we
      # can run bhyve, bhyveload and pf with sudo privilege
      def sudo
	@@sudo = '' if Process.uid == 0
	@@sudo = 'sudo'
      end

      def state(&block)
	IO.popen("test -e #{name}").tap { |f| f.read }.close
	return :running if $?.success?
	return :not_running
      end

    end
  end
end
