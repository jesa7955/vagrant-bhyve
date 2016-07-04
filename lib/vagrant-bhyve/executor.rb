require "vagrant/util/busy"
require "vagrant/util/subprocess"

module VagrantPlugins
  module ProviderBhyve
    module Executor
      # This class is used to execute commands as subprocess.
      class Exec
	# When we need the command's exit code we should set parameter 
	# exit_code to true, otherwise this method will return executed
	# command's stdout
	def execute(exit_code, *cmd, **opts, &block)
	  # Append in the options for subprocess
	  cmd << { notify: [:stdout, :stderr] }
	  cmd.unshift('sh', '-c')

	  interrupted = false
	  # Lambda to change interrupted to true
	  int_callback = ->{ interrupted = true }
	  result = ::Vagrant::Util::Busy.busy(int_callback) do
	    ::Vagrant::Util::Subprocess.execute(*cmd, &block)
	  end

	  return result.exit_code if exit_code

	  result.stderr.gsub!("\r\n", "\n")
	  result.stdout.gsub!("\r\n", "\n")

	  if result.exit_code != 0 || interrupted
	    raise Errors::ExecuteError
	  end

	  result.stdout[0..-2]
	end
      end
    end
  end
end
