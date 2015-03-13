# This test setup was taken from sidekiq-middleware:
# https://github.com/krasnoukhov/sidekiq-middleware/blob/v0.3.0/test/test_unique_jobs.rb

require 'celluloid'
Celluloid.logger = nil

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
  repeat { minutely }

  def perform; end
end

class SidekiqRepeatArgumentsTestJob
  include Sidekiq::Worker
  include Sidekiq::Repeat::Repeatable
  repeat { minutely }

  class << self
    attr_accessor :last, :current
  end

  def perform(last, current)
    self.class.last    = last
    self.class.current = current
  end
end

UnitOfWork = Struct.new(:queue, :message) do
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
      define_method(:perform_args) { perform_with_arguments ? [(Time.now - 60).to_f, Time.now.to_f] : [] }

      def self.included(base)
        base.include Assertions
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
      actor.expect(:real_thread, nil, [nil, Celluloid::Thread])
      2.times { @boss.expect(:async, actor, []) }
      @processor.process(work)
    end
  end

  module CelluloidSetup
    def setup
      Celluloid.boot
      @boss = MiniTest::Mock.new
      @processor = Sidekiq::Processor.new(@boss)
      @processor.fire_event(:startup)
    end
  end
end
