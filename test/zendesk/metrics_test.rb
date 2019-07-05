require "bundler/setup"
require "minitest/autorun"
require "./inspect_tickets"

module Zendesk
  class MetricsTest < Minitest::Test
    def test_mean_and_std
      data = [
        3145,
        211,
        1318,
        1167,
        42,
        158,
        175,
      ]

      mean = 888
      std = 1124

      results = Zendesk::Metrics.mean_and_std(data)
      assert_equal mean, results[:mean]
      assert_equal  std, results[:std]
    end
  end
end

