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

  spec.add_dependency 'sidekiq', '>= 6', '< 7.0'
  spec.add_dependency 'parse-cron', '~> 0.1'
  spec.add_dependency 'redlock', '~> 1'

  spec.add_development_dependency 'minitest', '~> 3'
  spec.add_development_dependency 'rake', '>= 12.3.3'
  spec.add_development_dependency 'redis-namespace', '~> 1.3'
  spec.add_development_dependency 'appraisal', '~> 2.2'
end
