# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-papertrail"
  spec.version       = "0.2.5"
  spec.authors       = ["Jonathan Lozinski", "Alex Ouzounis", "Chris Rust"]
  spec.email         = ["jonathan.lozinski@solarwinds.com", "alex.ouzounis@solarwinds.com", "chris.rust@solarwinds.com"]

  spec.summary       = %q{Remote Syslog Output Fluentd plugin for papertrail}
  spec.description   = %q{Remote Syslog Output Fluentd plugin for papertrail}
  spec.homepage      = "https://github.com/solarwinds/fluent-plugin-papertrail"
  spec.license       = "Apache-2.0"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "fluentd", '>= 0.10', '< 2'
  spec.add_dependency "fluent-mixin-config-placeholders", "~> 0.4.0"
  spec.add_dependency "syslog_protocol"

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "test-unit", "~> 3.2"
end
