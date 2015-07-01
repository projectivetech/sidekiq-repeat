require 'singleton'

module Sidekiq
  module Repeat
    class Configuration
      include Singleton

      def initialize
        reset_to_default!
      end

      def reset_to_default!
        @redlock_enabled          = true
        @redlock_redis_instances  = ['redis://localhost:6379']
      end

      attr_accessor :redlock_enabled
      attr_accessor :redlock_redis_instances

      def self.with_lock
        if instance.redlock_enabled
          Redlock::Client.new(instance.redlock_redis_instances).lock('sidekiq-repeat-reschedule-all', 500) do
            yield
          end
        else
          yield
        end
      end
    end
  end
end
