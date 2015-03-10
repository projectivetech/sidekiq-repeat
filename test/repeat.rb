require 'minitest/autorun'

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

UnitOfWork = Struct.new(:queue, :message) do
  def acknowledge; end
  def queue_name; end
  def requeue; end
end

class TestRescheduling < MiniTest::Unit::TestCase
  def scheduled_jobs
    Sidekiq::ScheduledSet.new.select { |i| i.klass == 'SidekiqRepeatTestJob' }
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
    msg = Sidekiq.dump_json('class' => 'SidekiqRepeatTestJob', 'queue' => 'default', 'args' => [])
    work = UnitOfWork.new('default', msg)
    actor = MiniTest::Mock.new
    actor.expect(:processor_done, nil, [@processor])
    actor.expect(:real_thread, nil, [nil, Celluloid::Thread])
    2.times { @boss.expect(:async, actor, []) }
    @processor.process(work)
  end

  def setup
    Celluloid.boot
    @boss = MiniTest::Mock.new
    @processor = Sidekiq::Processor.new(@boss)
    @processor.fire_event(:startup)
  end

  def test_reschedules_itself_on_startup
    assert_scheduled
  end

  def test_does_not_reschedule_if_already_scheduled
    assert_scheduled

    perform_scheduled!

    assert_scheduled
  end

  def test_reschedules_itself_after_run
    # Manually drain the scheduled set.
    delete_scheduled!
    assert_not_scheduled

    perform_scheduled!

    assert_scheduled
  end
end
