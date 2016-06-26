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

      class UnableToLoadModule < VagrantBhyveError
	error_key(:unable_to_load_module)
      end

      class UnableToCreateBridge < VagrantBhyveError
	error_key(:unable_to_create_bridge)
      end

      class GrubBhyveNotinstalled < VagrantBhyveError
	error_key(:grub_bhyve_not_installed)
      end

      class RestartServiceFailed < VagrantBhyveError
	error_key(:restart_service_failed)
      end
    end
  end
end
