require 'parse-cron'
require 'redlock'
require 'sidekiq'
require 'sidekiq/api'

require 'sidekiq/repeat/configuration'
require 'sidekiq/repeat/middleware'
require 'sidekiq/repeat/mini_ice_cube'
require 'sidekiq/repeat/repeatable'
require 'sidekiq/repeat/version'

module Sidekiq
  module Repeat
    def self.configure
      yield Configuration.instance
    end
  end
end
