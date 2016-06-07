require "vagrant/util/subprocess"
require "log4r"

module VagrantPlugins
  module ProviderBhyve
    class Driver
      
      @@sudo = ''

      def initialize(machine)
	@logger = Log4r::Logger.new("vagrant::bhyve::driver")
	@machine = machine
      end

      # if vagrant is excecuted by root (or with sudo) then the variable
      # will be empty string, otherwise it will be 'sudo' to make sure we
      # can run bhyve, bhyveload and pf with sudo privilege
      def sudo
	if Process.uid == 0
	  @@sudo = ''
	else
	  @@sudo = 'sudo'
	end
      end

      def execute(command)
	process = Subprocess.new(command)
	process.execute
      end

    end
  end
end
