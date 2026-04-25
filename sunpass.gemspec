# frozen_string_literal: true

require_relative 'lib/sunpass/version'

Gem::Specification.new do |spec|
  spec.name = 'sunpass'
  spec.version = Sunpass::VERSION
  spec.authors = ['SunPass Automation Contributors']
  spec.summary = 'Fetch SunPass transactions and transponders through the web UI'
  spec.description = 'Automates SunPass UI login and extracts transaction and transponder data into Ruby objects.'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 4.0'

  spec.files = Dir.glob('{lib,bin}/**/*').select { |f| File.file?(f) } + %w[sunpass.gemspec README.md]
  spec.bindir = 'bin'
  spec.executables = ['fetch_transactions']
  spec.require_paths = ['lib']

  spec.add_dependency 'playwright-ruby-client', '~> 1.44'
  spec.add_dependency 'json', '~> 2.7'
  spec.add_dependency 'dotenv', '~> 3.1'

  spec.add_development_dependency 'minitest', '~> 5.25'
end
