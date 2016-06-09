require "vagrant"

module VagrantPlugins
  module ProviderBhyve
    module Errors
      class VagrantBhyveError < Vagrant::Errors::VagrantError
	error_namespace('vagrant_bhyve.errors')
      end

      class HasNoRootPrivilege << VagrantBhyveError
	error_key(:has_no_root_privilege)
      end

      class ExecuteError << VagrantBhyveError
	error_key(:execute_error)
      end

    end
  end
end
