require "pathname"
require "vagrant/action/builder"

module VagrantPlugins
  module ProviderBhyve
    module Action
      include Vagrant::Action::Builtin

      action_root = Pathname.new(File.expand_path('../action', __FILE__))
      autoload :Boot, action_root.join('boot')
      autoload :CreateBridge, action_root.join('create_bridge')
      autoload :CreateTap, action_root.join('create_tap')
      autoload :Cleanup, action_root.join('cleanup')
      autoload :Destroy, action_root.join('destroy')
      autoload :ForwardPorts, action_root.join('forward_ports')
      autoload :Import, action_root.join('import')
      autoload :Load, action_root.join('load')
      autoload :PrepareNFSSettings, action_root.join('prepare_nfs_settings')
      autoload :PrepareNFSValidIds, action_root.join('prepare_nfs_valid_ids')
      autoload :Setup, action_root.join('setup')
      autoload :Shutdown, action_root.join('shutdown')
      autoload :WaitUntilUP, action_root.join('wait_until_up')

      def self.action_boot
	Vagrant::Action::Builder.new.tap do |b|
	  b.use CreateBridge
	  b.use CreateTap
	  b.use Load
	  b.use Boot
	  b.use Call, WaitUntilUP do |env, b1|
	    if env[:uncleaned]
	      b1.use action_reload
	    else
	      b1.use ForwardPorts
	    end
	  end
	  b.use PrepareNFSValidIds
	  b.use SyncedFolderCleanup
	  b.use SyncedFolders
	  b.use PrepareNFSSettings
	end
      end

      def self.action_halt
	Vagrant::Action::Builder.new.tap do |b|
	  b.use ConfigValidate
	  b.use Call, IsState, :running do |env, b1|
	    if env[:result]
	      b1.use Call, GracefulHalt, :uncleaned, :running do |env1, b2|
	        if !env1[:result]
		  b3.use Shutdown
	        end
	      end
	    end
	  end
	  b.use Call, IsState, :uncleaned do |env, b1|
	    if env[:result]
	      b1.use Cleanup
	    end
	  end
	end
      end

      def self.action_reload
	Vagrant::Action::Builder.new.tap do |b|
	  b.use Message, I18n.t('vagrant_bhyve.action.vm.reload.reloading')
	  b.use Call, IsState, Vagrant::MachineState::NOT_CREATED_ID do |env, b1|
	    if env[:result]
	      b1.use Message, I18n.t('vagrant_bhyve.commands.common.vm_not_created')
	      next
	    end
	    b1.use Call, IsState, :stopped do |env1, b2|
	      if !env1[:result]
		b2.use action_halt
	      end
	    end
	    b1.use ConfigValidate
	    b1.use action_start
	  end
	end
      end

      def self.action_ssh
	Vagrant::Action::Builder.new.tap do |b|
	  b.use ConfigValidate
	  b.use Call, IsState, :running do |env, b1|
	    if !env[:result]
	      b1.use Message, I18n.t('vagrant_bhyve.commands.common.vm_not_running')
	      next
	    end
	    b1.use SSHExec
	  end
	end
      end

      def self.action_ssh_run
	Vagrant::Action::Builder.new.tap do |b|
	  b.use ConfigValidate
	  b.use Call, IsState, :running do |env, b1|
	    if !env[:result]
	      b1.use Message, I18n.t('vagrant_bhyve.commands.common.vm_not_running')
	      next
	    end
	    b1.use SSHRun
	  end
	end
      end

      def self.action_start
	Vagrant::Action::Builder.new.tap do |b|
	  b.use ConfigValidate
	  b.use Call, IsState, :running do |env, b1|
	    if env[:result]
	      b1.use Message, I18n.t('vagrant_bhyve.commands.common.vm_already_running')
	      next
	    end
	    b1.use Call, IsState, :uncleaned do |env1, b2|
	      if env1[:result]
		b2.use Cleanup
	      end
	    end
	    b1.use Setup
	    b1.use action_boot
	  end
	end
      end

      def self.action_up
	Vagrant::Action::Builder.new.tap do |b|
	  b.use Call, IsState, Vagrant::MachineState::NOT_CREATED_ID do |env, b1|
	    if env[:result]
	      b1.use HandleBox
	    end
	  end

	  b.use ConfigValidate
	  b.use Call, IsState, Vagrant::MachineState::NOT_CREATED_ID do |env,b1|
	    if env[:result]
	      b1.use Import
	      b1.use Provision
	    end
	  end
	  b.use action_start
	end
      end

      def self.action_destroy
	Vagrant::Action::Builder.new.tap do |b|
	  b.use ConfigValidate
	  b.use Call, IsState, Vagrant::MachineState::NOT_CREATED_ID do |env, b1|
	    if env[:result]
	      b1.use Message, I18n.t('vagrant_bhyve.commands.common.vm_not_created')
	      next
	    end

	    b1.use Call, DestroyConfirm do |env1, b2|
	      if !env1[:result]
		b2.use Message, I18n.t(
		  'vagrant.commands.destroy.will_not_destroy',
		  name: env1[:machine].name)
		next
	      end
	      b2.use Call, IsState, :running do |env2, b3|
		if env2[:result]
		  b3.use action_halt
		end
	      end
	      b2.use Call, IsState, :uncleaned do |env2, b3|
		if env2[:result]
		  b3.use Cleanup
		end
	      end
	      b2.use Destroy
	      b2.use ProvisionerCleanup
	      b2.use PrepareNFSValidIds
	      b2.use SyncedFolderCleanup
	    end
	  end
	end
      end

      def self.action_provision
	Vagrant::Action::Builder.new.tap do |b|
	  b.use ConfigValidate
	  b.use Call, IsState, Vagrant::MachineState::NOT_CREATED_ID do |env,b1|
	    if env[:result]
	      b1.use Message, I18n.t('vagrant_bhyve.commands.common.vm_not_created')
	      next
	    end
	    b1.use Call, IsState, :running do |env1, b2|
	      if !env1[:result]
		b2.use Message, I18n.t('vagrant_bhyve.commands.common.vm_not_running')
		next
	      end
	      b2.use Provision
	    end
	  end
	end
      end

      def self.action_suspend
	Vagrant::Action::Builder.new.tap do |b|
	  b.use Warn, I18n.t('vagrant_bhyve.actions.vm.suspend.not_supported')
	end
      end

      def self.action_resume
	Vagrant::Action::Builder.new.tap do |b|
	  b.use Warn, I18n.t('vagrant_bhyve.actions.vm.resume.not_supported')
	end
      end

    end
  end
end
