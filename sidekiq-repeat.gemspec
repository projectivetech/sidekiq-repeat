$:.unshift File.expand_path('../lib', __FILE__)
require 'sidekiq/repeat/version'

Gem::Specification.new do |spec|
  spec.name          = 'sidekiq-repeat'
  spec.version       = Sidekiq::Repeat::VERSION
  spec.authors       = ['Projective Technology GmbH']
  spec.email         = 'technology@projective.io'
  spec.homepage      = 'https://github.com/projectivetech/sidekiq-repeat'
  spec.summary       = 'Repeat is a clockless recurring job system for Sidekiq.'
  spec.description   = 'This gem adds recurring jobs to Sidekiq. It is heavily inspired by the sidekiq-dejavu and sidetiq gems.'
  spec.license       = 'MIT'

  spec.files         = Dir['lib/**/*rb']
  spec.require_paths = ['lib']

  spec.add_dependency 'sidekiq', '~> 6.5', '>= 6.5.12'
  spec.add_dependency 'parse-cron', '~> 0.1.4'
  spec.add_dependency 'redlock', '~> 1.3', '>= 1.3.2'
  # Sidekiq 6.5 requires these libraries without declaring them as gems.
  spec.add_dependency 'base64', '~> 0.3'
  spec.add_dependency 'logger', '~> 1.7'

  spec.add_development_dependency 'minitest', '~> 5.25'
  spec.add_development_dependency 'rake', '~> 13.3'
  spec.add_development_dependency 'simplecov', '~> 1.0'
end
