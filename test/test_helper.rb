# This test setup was taken from sidekiq-middleware:
# https://github.com/krasnoukhov/sidekiq-middleware/blob/v0.3.0/test/test_unique_jobs.rb

require 'simplecov'
SimpleCov.start do
  cover 'lib/**/*.rb'
end

require 'minitest/autorun'
require 'sidekiq'
require 'sidekiq/cli'
require 'minitest/mock'

Sidekiq.testing!(:disable)
Sidekiq.logger.level = Logger::ERROR
configure_sidekiq = proc do |config|
  config.redis = {
    url: ENV.fetch('TEST_REDIS_URL', 'redis://127.0.0.1:16379')
  }
end
Sidekiq.configure_client(&configure_sidekiq)
Sidekiq.configure_server(&configure_sidekiq)

require 'sidekiq-repeat'

Sidekiq::Testing.server_middleware do |chain|
  chain.add Sidekiq::Repeat::Middleware
end

class SidekiqRepeatTestJob
  include Sidekiq::Worker
  include Sidekiq::Repeat::Repeatable
  repeat { hourly }

  def perform; end
end

class SidekiqRepeatArgumentsTestJob
  include Sidekiq::Worker
  include Sidekiq::Repeat::Repeatable
  repeat { hourly }

  class << self
    attr_accessor :last, :current
  end

  def perform(last, current)
    self.class.last    = last
    self.class.current = current
  end
end

module TestHelper
  LOCK_KEY = 'sidekiq-repeat-reschedule-all'

  def self.second_redis_pool
    @second_redis_pool ||= begin
      primary_db = Sidekiq.redis { |redis| redis.config.db }
      client = RedisClient.config(url: ENV.fetch('TEST_REDIS_URL', 'redis://127.0.0.1:16379'), db: primary_db == 1 ? 0 : 1)
      client.new_pool(size: 1)
    end
  end

  def self.assertions(klass, perform_with_arguments = false)
    Module.new do
      # NOTE: For some reason, we need to use define_method here, as otherwise `klass`
      #       and `arguments are undefined in the methods.
      define_method(:klass_name) { klass }
      define_method(:perform_args) { perform_with_arguments ? [(Time.now - 60 * 60).to_f, Time.now.to_f] : [] }

      def self.included(base)
        base.include Assertions
      end
    end
  end

  def self.application_setup(startup_sidekiq = true, &block)
    Module.new do
      define_method(:startup_sidekiq) { startup_sidekiq }

      def self.included(base)
        base.include ApplicationSetup
      end
    end
  end

  module Assertions
    def scheduled_jobs
      Sidekiq::ScheduledSet.new.select { |i| i.klass == klass_name }
    end

    def assert_scheduled(size = 1)
      assert_equal size, scheduled_jobs.size
    end

    def assert_not_scheduled
      assert_scheduled 0
    end

    def delete_scheduled!
      scheduled_jobs.map(&:delete)
    end

    # Enqueues a job in memory with +fake!+, then executes it with +perform_one+, the purpose is to only use public
    # Sidekiq API. During execution, testing is disabled, so the middleware schedules the next occurrence in Redis.
    def perform_scheduled!
      worker = Object.const_get(klass_name)
      Sidekiq::Testing.fake! { worker.perform_async(*perform_args) }
      worker.perform_one
    end

    def with_redlock_held(redis = Sidekiq.redis_pool)
      client = Redlock::Client.new([redis], retry_count: 0)
      lock = client.lock(TestHelper::LOCK_KEY, 30_000)
      raise 'Could not acquire test lock' unless lock

      yield
    ensure
      client.unlock(lock) if lock
    end
  end

  module ApplicationSetup
    def run
      Time.stub(:now, Time.local(2030, 1, 2, 12, 10, 30)) { super }
    end

    def configure(config)
      # To be overwritten in test class.
    end

    def setup
      clear_test_redis
      Sidekiq::Repeat::Repeatable.repeatables.each do |klass|
        klass.repeat { hourly }
        klass.instance_variable_set(:@cronline, nil)
        klass.instance_variable_set(:@ss, nil)
      end
      Sidekiq::Repeat::Configuration.instance.redlock_redis_instances = [Sidekiq.redis_pool]
      # Allow the test to configure Sidekiq::Repeat.
      Sidekiq::Repeat.configure { |config| configure(config) }

      startup_sidekiq! if startup_sidekiq
    end

    def teardown
      clear_test_redis
      # Reset to defaults for next test case.
      Sidekiq::Repeat::Configuration.instance.reset_to_default!
    end

    def startup_sidekiq!
      Sidekiq.default_configuration[:lifecycle_events][:startup].each(&:call)
    end

    def clear_test_redis
      Sidekiq.redis(&:flushdb)
      TestHelper.second_redis_pool.with { |redis| redis.call('DEL', TestHelper::LOCK_KEY) }
    end
  end
end
