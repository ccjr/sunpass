# frozen_string_literal: true

require_relative 'lib/sunpass/version'

Gem::Specification.new do |spec|
  spec.name = 'sunpass'
  spec.version = Sunpass::VERSION
  spec.authors = ['SunPass Automation Contributors']
  spec.summary = 'Automate SunPass transaction retrieval and persistence'
  spec.description = 'Automates SunPass UI login/transaction extraction, normalizes rows, and persists records into SQLite.'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 4.0'

  spec.files = Dir.glob('{lib,bin}/**/*').select { |f| File.file?(f) } + %w[sunpass.gemspec README.md]
  spec.bindir = 'bin'
  spec.executables = ['fetch_transactions']
  spec.require_paths = ['lib']

  spec.add_dependency 'playwright-ruby-client', '~> 1.44'
  spec.add_dependency 'sequel', '~> 5.80'
  spec.add_dependency 'sqlite3', '~> 1.7'
  spec.add_dependency 'json', '~> 2.7'
  spec.add_dependency 'dotenv', '~> 3.1'
end
