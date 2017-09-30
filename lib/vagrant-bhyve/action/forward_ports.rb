require "log4r"

module VagrantPlugins
  module ProviderBhyve
    module Action
      class ForwardPorts

	def initialize(app, env)
	  @logger = Log4r::Logger.new("vagrant_bhyve::action::forward_ports")
	  @app = app
	end

	def call(env)
	  @machine              = env[:machine]
	  @driver               = @machine.provider.driver
	  @ui                   = env[:ui]

	  @ui.info I18n.t('vagrant_bhyve.action.vm.forward_ports')

	  env[:forwarded_ports]  = compile_forwarded_ports(@machine.config)
	  tap_device            = @driver.get_attr('tap')
	  gateway               = @driver.get_attr('gateway')
	  env[:forwarded_ports].each do |item|
	    forward_information = {
	      adapter: item[:adapter] || gateway,
	      guest_port: item[:guest],
	      host_port: item[:host]
	    }
	    @driver.forward_port(forward_information, tap_device, @ui)
	  end
	  @app.call(env)
	end

	private

	def compile_forwarded_ports(config)
	  mappings = {}
	  config.vm.networks.each do |type, options|
	    next if options[:disabled]

	    if type == :forwarded_port && options[:id] != 'ssh'
	      if options.fetch(:host_ip, '').to_s.strip.empty?
		options.delete(:host_ip)
	      end
	      mappings[options[:host]] = options
	    end
	  end
	  mappings.values

	end
      end
    end
  end
end
