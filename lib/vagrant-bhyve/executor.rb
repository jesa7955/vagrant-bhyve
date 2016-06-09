require "vagrant/util/busy"
require "vagrant/util/subprocess"

module VagrantPlugins
  module ProviderBhyve
    module Executor
      # This class is used to execute commands as subprocess.
      class Exec
	# When test is true, this method will return the executed command's
	# exit code. Otherwise it will return the result's stdout
	def execute(test, *cmd, **opts, &block)
	  # Append in the options for subprocess
	  cmd << { notify: [:stdout, :stderr] }

	  interrupted = false
	  # Lambda to change interrupted to true
	  int_callback = ->{ interrupted = true }
	  result = ::Vagrant::Util::Busy.busy(int_callback) do
	    ::Vagrant::Util::Subprocess.execute(*cmd, &block)
	  end

	  return result.exit_code if test

	  result.stderr.gsub!("\r\n", "\n")
	  result.stdout.gsub!("\r\n", "\n")

	  if result.exit_code != 0 && interrupted
	    raise Errors::ExecuteError,
	      command: cmd.inspect,
	      stderr: result.stderr,
	      stdout: result.stdout
	  end

	  result.stdout
	end
      end
    end
  end
end
