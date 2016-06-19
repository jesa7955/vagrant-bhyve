require "pathname"

module VagrantPlugins
  module ProviderBhyve
    module Action
      include Vagrant::Action::Builtin

      action_root = Pathname.new(File.expand_path('../action', __FILE__))
      autoload :Setup, action_root.join('setup')
      autoload :CreateSwitch, action_root.join('create_switch')
      autoload :CreateTap, action_root.join('create_tap')
      autoload :Load, action_root.join('load')
      autoload :Boot, action_root.join('boot')
      autoload :ForwardPorts, action_root.join('forward_ports')
      autoload :Shutdown, action_root.join('shudown')

      def self.action_boot
	Vagrant::Action::Builder.new.tap do |b|
	  b.use Setup
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
	      ######
	      next
	    end

	    b1.use Call, GracefulHalt, :not_running, :running do |env1, b2|
	      if !env1[:result]
		b2.use Shutdown
	      end
	    end
	    #b1.user Cleanup
	  end
	end
      end

      def self.action_up
	Vagrant::Action::Builder.new.tap do |b|
	  b.use Call, IsState, Vagrant::MachineState::NOT_CREATE_ID do |env, b1|
	    if env[:result]
	      b2.use HandleBox
	    end
	  end

	  b.use ConfigValidate
	  b.use Call, IsState, Vagrant::MachineState::NOT_CREATE_ID do |env,b1|
	    if env[:result]
	      b1.use Import
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
