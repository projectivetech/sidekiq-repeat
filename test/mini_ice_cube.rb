require 'minitest/autorun'
require 'sidekiq/repeat/mini_ice_cube'

class TestMiniIceCube < MiniTest::Unit::TestCase
  def setup
    @dsl = Sidekiq::Repeat::MiniIceCube::MainDsl.new
  end

  def parse(&block)
    @dsl.instance_eval(&block).to_s
  end

  def test_weekly
    assert_equal '0 3 * * 0', parse { weekly }
  end

  def test_hourly_without_interval
    assert_equal '0 * * * *', parse { hourly }
  end

  def test_minutely_with_interval_exact
    assert_equal '0,10,20,30,40,50 * * * *', parse { minutely(10) }
  end

  def test_minutely_with_interval_random
    cron  = parse { minutely(13) }
    parts = cron.split(' ')
    assert_equal (['*'] * 4), parts[1..-1]
    mp    = parts[0].split(',')
    assert_equal 4, mp.size
  end

  def test_minute_of_hour
    assert_equal '15,45 0,4,8,12,16,20 * * *', parse { hourly(4).minute_of_hour(15, 45) }
  end
end
