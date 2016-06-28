require "pathname"
require "vagrant/action/builder"

module VagrantPlugins
  module ProviderBhyve
    module Action
      include Vagrant::Action::Builtin

      action_root = Pathname.new(File.expand_path('../action', __FILE__))
      autoload :Setup, action_root.join('setup')
      autoload :Import, action_root.join('import')
      autoload :CreateSwitch, action_root.join('create_switch')
      autoload :CreateTap, action_root.join('create_tap')
      autoload :Cleanup, action_root.join('cleanup')
      autoload :Load, action_root.join('load')
      autoload :Boot, action_root.join('boot')
      autoload :ForwardPorts, action_root.join('forward_ports')
      autoload :Shutdown, action_root.join('shutdown')

      def self.action_boot
	Vagrant::Action::Builder.new.tap do |b|
	  b.use CreateSwitch
	  b.use CreateTap
	  b.use Load
	  b.use Boot
	  b.use WaitForCommunicator, [:running]
	end
      end

      def self.action_halt
	Vagrant::Action::Builder.new.tap do |b|
	  b.use ConfigValidate
	  b.use Call, IsState, :running do |env, b1|
	    if !env[:result]
	      next
	    end

	    b1.use Call, GracefulHalt, :not_running, :running do |env1, b2|
	      if !env1[:result]
		b2.use Shutdown
	      end
	    end
	    b1.use Cleanup
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

      def self.action_start
	Vagrant::Action::Builder.new.tap do |b|
	  b.use ConfigValidate
	  b.use Call, IsState, :runnig do |env, b1|
	    if env[:result]
	      b1.use Message, I18n.t('vagrant_bhyve.commands.common.vm_already_running')
	      next
	    end

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
	      b1.use Setup
	      b1.use Import
	    end
	  end
	  b.use action_start
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
