# coding: utf-8
require File.expand_path('../lib/vagrant-bhyve/version', __FILE__)

Gem::Specification.new do |spec|
  spec.name          = "vagrant-bhyve"
  spec.version       = VagrantPlugins::ProviderBhyve::VERSION
  spec.authors       = ["Tong Li"]
  spec.email         = ["jesa7955@gmail.com"]

  spec.summary       = %q{Vagrant provider plugin to support bhyve}
  spec.description   = spec.summary
  spec.homepage      = "https://github.com/jesa7955/vagrant-bhyve"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_runtime_dependency "ruby_expect"
end
