require "bundler/setup"
require "minitest/autorun"
require "./inspect_tickets"

module Zendesk
  class BusinessTimeTest < Minitest::Test
    def test_count_holidays_with_no_holidays
      begin_date = "2019-07-01" # Mon
      end_date = "2019-07-05" # Fri

      assert_equal 0, Zendesk::BusinessTime.count_holidays(begin_date, end_date)
    end

    def test_count_holidays_only_with_weekend
      begin_date = "2019-07-04" # Thur
      end_date = "2019-07-08" # Mon

      assert_equal 2, Zendesk::BusinessTime.count_holidays(begin_date, end_date)
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
  end
end
