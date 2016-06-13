require "vagrant"

module VagrantPlugins
  module ProviderBhyve
    module Errors
      class VagrantBhyveError < Vagrant::Errors::VagrantError
	error_namespace('vagrant_bhyve.errors')
      end

      class SystemVersionIsTooLow < VagrantBhyveError
	error_key(:system_version_too_low)
      end

      class MissingPopcnt < VagrantBhyveError
	error_key(:missing_popcnt)
      end

      class MissingEpt < VagrantBhyveError
	error_key(:missing_ept)
      end

      class MissingIommu < VagrantBhyveError
	error_key(:missing_iommu)
      end

      class HasNoRootPrivilege < VagrantBhyveError
	error_key(:has_no_root_privilege)
      end

      class ExecuteError < VagrantBhyveError
	error_key(:execute_error)
      end

      class UnableToLoadModule < VagrantError
	error_key(:unable_to_load_module)
      end

      class UnableToCreateBridge < VagrantError
	error_key(:unable_to_create_brighe)
      end

      class UnrecognizedLoader < VagrantError
	error_key(:unrecognized_loader)
      end

      class GrubBhyveNotinstalled < VagrantError
	error_key(:grub_bhyve_not_installed)
      end
    end
  end
end
