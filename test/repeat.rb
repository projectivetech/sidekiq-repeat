require 'minitest/autorun'

require_relative './test_helper.rb'

class TestRescheduling < MiniTest::Unit::TestCase
  include TestHelper.assertions('SidekiqRepeatTestJob')
  include TestHelper.application_setup

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

  def test_reschedules_job_if_in_the_future
    assert_scheduled

    if scheduled_jobs.first.at.to_f - Time.now.to_f <= 60
      # If the next schedule is in less than a minute, this test case doesn't make sense.
      skip
    end

    # Change the recurrence to minutely.
    SidekiqRepeatTestJob.class_eval do
      repeat { minutely }
    end

    SidekiqRepeatTestJob.reschedule

    assert_in_delta Time.now.to_f + 60, scheduled_jobs.first.at.to_f, 60

    # Change back to hourly default.
    SidekiqRepeatTestJob.class_eval do
      repeat { hourly }
    end
  end
end

class TestArguments < MiniTest::Unit::TestCase
  include TestHelper.assertions('SidekiqRepeatArgumentsTestJob', true)
  include TestHelper.application_setup

  def test_perform_called_with_parameters
    perform_scheduled!
    assert_in_delta Time.now.to_f, SidekiqRepeatArgumentsTestJob.current, 0.1
    assert_in_delta (SidekiqRepeatArgumentsTestJob.current - SidekiqRepeatArgumentsTestJob.last), 60 * 60, 0.1
  end
end

class TestRedlockDefaultConfiguration < MiniTest::Unit::TestCase
  include TestHelper.assertions('SidekiqRepeatTestJob')
  include TestHelper.application_setup(false)

  def test_startup_scheduling_is_locked
    expect_redlock! { startup_sidekiq! }
  end
end

class TestRedlockDisabled < MiniTest::Unit::TestCase
  include TestHelper.assertions('SidekiqRepeatTestJob')
  include TestHelper.application_setup(false)

  def configure(config)
    config.redlock_enabled = false
  end

  def test_startup_scheduling_is_not_locked
    expect_no_redlock! { startup_sidekiq! }
  end
end

class TestRedlockMultipleRedisInstances < MiniTest::Unit::TestCase
  include TestHelper.assertions('SidekiqRepeatTestJob')
  include TestHelper.application_setup(false)

  def configure(config)
    config.redlock_redis_instances = ['redis://1.2.3.4/', 'redis://5.6.7.8/']
  end

  def test_startup_scheduling_is_not_locked
    expect_redlock!(['redis://1.2.3.4/', 'redis://5.6.7.8/']) { startup_sidekiq! }
  end
end
