# This test setup was taken from sidekiq-middleware:
# https://github.com/krasnoukhov/sidekiq-middleware/blob/v0.3.0/test/test_unique_jobs.rb

require 'sidekiq'
require 'sidekiq/cli'
require 'sidekiq/processor'
require 'sidekiq/redis_connection'
Sidekiq.logger.level = Logger::ERROR
Sidekiq.redis = Sidekiq::RedisConnection.create(:namespace => 'sidekiq-repeat-test')

require 'sidekiq-repeat'

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

UnitOfWork = Struct.new(:queue, :job) do
  def acknowledge; end
  def queue_name; end
  def requeue; end
end

module TestHelper
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

    def perform_scheduled!
      msg = Sidekiq.dump_json('class' => klass_name, 'queue' => 'default', 'args' => perform_args)
      work = UnitOfWork.new('default', msg)
      actor = MiniTest::Mock.new
      actor.expect(:processor_done, nil, [@processor])
      2.times { @boss.expect(:async, actor, []) }
      @processor.send(:process, work)
    end

    def expect_redlock!(redis_instances = nil)
      redis_instances ||= Sidekiq::Repeat::Configuration.instance.redlock_redis_instances

      @redlock_client_instance = MiniTest::Mock.new
      @redlock_client_instance.expect(:lock, nil, ['sidekiq-repeat-reschedule-all', 500])

      @redlock_client_new_method = MiniTest::Mock.new
      @redlock_client_new_method.expect(:call, @redlock_client_instance, [redis_instances])

      Redlock::Client.stub(:new, @redlock_client_new_method) do
        yield  # to test case.
      end

      @redlock_client_new_method.verify
      @redlock_client_instance.verify
    end

    def expect_no_redlock!
      @redlock_client_new_method = Proc.new { flunk 'Redlock::Client::new should not be called' }
      Redlock::Client.stub(:new, @redlock_client_new_method) do
        yield
      end
    end
  end

  module ApplicationSetup
    def configure(config)
      # To be overwritten in test class.
    end

    def setup
      # Allow the test to configure Sidekiq::Repeat.
      Sidekiq::Repeat.configure { |config| configure(config) }

      @boss = MiniTest::Mock.new
      2.times { @boss.expect(:options, {:queues => ['default'] }, []) }
      @processor = Sidekiq::Processor.new(@boss, queues: ['default'])
      startup_sidekiq! if startup_sidekiq
    end

    def teardown
      # Reset to defaults for next test case.
      Sidekiq::Repeat::Configuration.instance.reset_to_default!
    end

    def startup_sidekiq!
      events = Sidekiq.options[:lifecycle_events][:startup].dup
      @processor.fire_event(:startup)
      Sidekiq.options[:lifecycle_events][:startup] = events
    end
  end
end
