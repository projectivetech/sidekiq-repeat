require 'minitest/autorun'
require 'sidekiq/repeat/mini_ice_cube'

class TestMiniIceCube < MiniTest::Unit::TestCase
  def setup
    @dsl = Sidekiq::Repeat::MiniIceCube::MainDsl.new
  end

  def parse(&block)
    @dsl.instance_eval(&block).to_s
  end

  def assert_valid_series(max, interval, s)
    parts = s.split(',').map(&:to_i)

    # Each run inside time frame.
    parts.each { |p| assert_includes 0..(max-1), p}

    parts.each_cons(2) do |i, j|
      # Monotonically increasing with steps == interval.
      assert_equal (j - i), interval
    end

    # At least interval between last run and first run in next time frame.
    assert_operator (parts.first + max - parts.last), :>=, interval
  end

  def test_weekly
    assert_equal '0 3 * * 0', parse { weekly }
  end

  def test_hourly_without_interval
    assert_equal '0 * * * *', parse { hourly }
  end

  def test_minutely_with_interval
    cron_parts = parse { minutely(13) }.split(' ')

    assert_valid_series 60, 13, cron_parts[0]
    assert_equal '* * * *', cron_parts[1..-1].join(' ')
  end

  def test_minute_of_hour
    cron_parts = parse { hourly(4).minute_of_hour(15, 45) }.split(' ')

    assert_equal '15,45', cron_parts[0]
    assert_valid_series 24, 4, cron_parts[1]
    assert_equal '* * *', cron_parts[2..-1].join(' ')
  end
end
