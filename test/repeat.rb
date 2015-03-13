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

require_relative './test_helper.rb'

class TestRescheduling < MiniTest::Unit::TestCase
  include TestHelper.assertions('SidekiqRepeatTestJob')
  include TestHelper::CelluloidSetup

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

class TestArguments < MiniTest::Unit::TestCase
  include TestHelper.assertions('SidekiqRepeatArgumentsTestJob', true)
  include TestHelper::CelluloidSetup

  def test_perform_called_with_parameters
    perform_scheduled!
    assert_in_delta Time.now.to_f, SidekiqRepeatArgumentsTestJob.current, 0.1
    assert_in_delta (SidekiqRepeatArgumentsTestJob.current - SidekiqRepeatArgumentsTestJob.last), 60, 0.1
  end
end
