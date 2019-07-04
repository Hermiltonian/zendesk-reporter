require "bundler/setup"
require "minitest/autorun"
require "./inspect_tickets"

module Zendesk
  class BusinessTimeTest < Minitest::Test
    def test_holiday_with_weekday
      assert_equal false, Zendesk::BusinessTime.holiday?("2019-07-01")
      assert_equal true, Zendesk::BusinessTime.bizday?("2019-07-01")
    end

    def test_holiday_with_weekend
      assert_equal true, Zendesk::BusinessTime.holiday?("2019-07-06")
      assert_equal false, Zendesk::BusinessTime.bizday?("2019-07-06")
    end

    def test_holiday_with_holiday
      assert_equal true, Zendesk::BusinessTime.holiday?("2019-10-22")
      assert_equal false, Zendesk::BusinessTime.bizday?("2019-10-22")
    end

    def test_count_holidays_with_no_holidays
      # begin_date = "2019-07-01" # Mon
      # end_date = "2019-07-05" # Fri
      begin_time = "2019-07-01T10:00:00+09:00" # Thur
      end_time = "2019-07-05T11:00:00+09:00" # Thur

      assert_equal 0, Zendesk::BusinessTime.count_holidays(begin_time, end_time)
    end

    def test_count_holidays_only_with_weekend
      begin_date = "2019-10-21T10:00:00+09:00" # Mon
      end_date = "2019-10-23T17:00:00+09:00" # Tue
      # begin_date = "2019-07-04" # Thur
      # end_date = "2019-07-08" # Mon

      assert_equal 1, Zendesk::BusinessTime.count_holidays(begin_date, end_date)
    end

    def test_count_holidays_only_with_holiday
      begin_date = "2019-10-21" # Mon, next day is 即位礼正殿の儀
      end_date = "2019-10-23" # Wed

      assert_equal 1, Zendesk::BusinessTime.count_holidays(begin_date, end_date)
    end

    def test_count_holidays_with_holiday_and_weekend
      # 2019-08-12 is 海の日の振替休日
      begin_date = "2019-08-09" # Fri
      end_date = "2019-08-14" # Wed

      assert_equal 3, Zendesk::BusinessTime.count_holidays(begin_date, end_date)
    end

    def test_count_holidays_end_date_is_holiday
      begin_date = "2019-07-05" # Fri
      end_date = "2019-07-06" # Sat

      assert_equal 1, Zendesk::BusinessTime.count_holidays(begin_date, end_date)
    end

    def test_biz_minutes_spent_between_same_day
      begin_time = "2019-07-04T10:00:00+09:00" # Thur
      end_time = "2019-07-04T11:00:00+09:00" # Thur

      assert_equal 60 * 1, Zendesk::BusinessTime.biz_minutes_spent(begin_time, end_time)
    end

    def test_biz_minutes_spent_with_weekday
      begin_time = "2019-07-04T10:00:00+09:00" # Thur
      end_time = "2019-07-05T10:00:00+09:00" # Fri

      assert_equal 60 * 24, Zendesk::BusinessTime.biz_minutes_spent(begin_time, end_time)
    end

    def test_biz_minutes_spent_end_date_is_holiday
      begin_time = "2019-07-04T10:00:00+09:00" # Thur
      end_time = "2019-07-07T10:00:00+09:00" # Sun

      assert_equal 60 * 24, Zendesk::BusinessTime.biz_minutes_spent(begin_time, end_time)
    end

    def test_biz_minutes_spent_with_weekend
      begin_time = "2019-07-04T10:00:00+09:00" # Thur
      end_time = "2019-07-08T10:00:00+09:00" # Sun

      assert_equal 60 * 24 * 2, Zendesk::BusinessTime.biz_minutes_spent(begin_time, end_time)
    end

    def test_biz_minutes_spent_only_with_holiday
      begin_time = "2019-10-21T10:00:00+09:00" # Mon
      end_time = "2019-10-23T17:00:00+09:00" # Tue

      assert_equal 60 * (24 * 1 + 7), Zendesk::BusinessTime.biz_minutes_spent(begin_time, end_time)
    end
  end
end
