require "log4r"

module VagrantPlugins
  module ProviderBhyve
    module Action
      class ForwardPort

	def initialize(app, env)
	  @logger = Log4r::Logger.new("vagrant_bhyve::action::forward_port")
	  @app = app
	end

	def call(env)
	  @env		= env
	  @driver	= env[:machine].provider.driver
	  @app.call(env)
	end

	def forward_ports
	  pf_conf = @env[:machine].box.directory.join('pf.conf').to_s
	  tap_device = @env[:tap]
	  @env[:forwarded_ports].each do |item|
	    forward_information = {
	      adapter: item[:adapter] || 'eth0',
	      guest_port: item[:guest],
	      host_port: item[:host]
	    }
	    @driver.forward_port(forward_information, pf_conf, tap_device)
	  end
	end

      end
    end
  end
end
