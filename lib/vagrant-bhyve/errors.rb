require "vagrant"

module VagrantPlugins
  module ProviderBhyve
    module Errors
      class VagrantBhyveError < Vagrant::Errors::VagrantError
	error_namespace('vagrant_bhyve.errors')
      end

      class NotRootUser << VagrantError
	error_key(:has_no_root_privilege)
      end

    end
  end
end
