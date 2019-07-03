require "bundler/setup"
require "holiday_japan"

module Zendesk
  require 'uri'
  require 'net/http'
  require "openssl"
  require "json"
  require "base64"

  class Ticket
    attr_reader :email
    attr_reader :token
    attr_reader :begin_date
    attr_reader :end_date

    def initialize
      begin
        file = File.open("./token.txt", "r")
      rescue
        puts "認証情報ファイル'token.txt'を準備してください。"
        return
      end

      file.each_line(chomp: true) do |line|
        key, *value = line.split("=")

        @email = value.join("=") if key == "email"
        @token = value.join("=") if key == "token"
      end

      file.close

      @begin_date = "2019-06-20T17:00:00+09:00"
      @end_date = "2019-06-27T17:00:00+09:00"
      # @begin_date = (Time.now - 3600 * 24 * 7).strftime("%FT17:00:00+09:00")
      # @end_date = (Time.now).strftime("%FT17:00:00+09:00")
    end

    def search_tickets(query)
      url = URI.parse("https://sample.zendesk.com/api/v2/search.json?#{query}")

      auth = "#{@email}/token:#{@token}"
      enc = Base64.encode64(auth).gsub("\n", "")
      headers = { Authorization: "Basic #{enc}" }

      req = Net::HTTP::Get.new(url, headers)

      response = Net::HTTP.start(url.host, url.port, use_ssl: url.scheme == 'https') do |http|
        http.request(req)
      end

      if response.header["X-Rate-Limit-Remaining"].to_i < 10
        puts "Rate Limit is low!! Please wait a minute for recovering"
        sleep(10)
      end

      raise RuntimeError unless response.is_a?(Net::HTTPSuccess)

      tickets = JSON.parse(response.body)
      tickets["results"].delete_if { |t| t["status"].nil? }

      tickets
    end

    def get_metrics(ticket_id)
      url = URI.parse("https://sample.zendesk.com/api/v2/tickets/#{ticket_id}/metrics.json")

      auth = "#{@email}/token:#{@token}"
      enc = Base64.encode64(auth).gsub("\n", "")
      headers = { Authorization: "Basic #{enc}" }

      req = Net::HTTP::Get.new(url, headers)

      response = Net::HTTP.start(url.host, url.port, use_ssl: url.scheme == 'https') do |http|
        http.request(req)
      end

      if response.header["X-Rate-Limit-Remaining"].to_i < 10
        puts "Rate Limit is low!! Please wait a minute for recovering"
        sleep(10)
      end

      raise RuntimeError unless response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    end

    def metrics(tickets)
      tickets["results"].map do |t|
        get_metrics(t["id"])
      end
    end

    def get_new_in_thisweek
      query = URI.encode_www_form([
        ["query", "created>#{self.begin_date} created<=#{self.end_date} type:ticket"],
        ["sort_by", "created_at"],
        ["sort_order", "asc"],
      ])

      search_tickets(query)
    end

    def new_in_thisweek(tickets)
      assignee = {
        HogeSan: [],
      }

      users = {
        "000000000000": "HogeSan",
      }

      tickets["results"].each do |t|
        user_name = users[t["assignee_id"].to_s.to_sym]
        assignee[user_name.to_sym] << t
      end

      puts "created: #{tickets["results"].length}"
      assignee.each do |user, t|
        puts "#{user.to_s}: #{t.length}"
      end

      tickets["results"].each do |t|
        puts "#{t["id"]}, #{t["status"]}, #{t["subject"]}"
      end
    end

    def solved_in_thisweek
      query = URI.encode_www_form([
        ["query", "solved>#{begin_date} solved<=#{end_date} type:ticket"],
        ["sort_by", "created_at"],
        ["sort_order", "asc"],
      ])

      tickets = search_tickets(query)

      assignee = {
        HogeSan: [],
      }

      users = {
        "000000000000": "HogeSan",
      }

      tickets["results"].each do |t|
        user_name = users[t["assignee_id"].to_s.to_sym]
        assignee[user_name.to_sym] << t
      end

      puts "solved: #{tickets["results"].length}"
      assignee.each do |user, t|
        puts "#{user.to_s}: #{t.length}"
      end

      tickets["results"].each do |t|
        puts "#{t["id"]}, #{t["status"]}, #{t["subject"]}"
      end
    end

    def unsolved
      query = URI.encode_www_form([
        ["query", "type:ticket status<solved"],
        ["sort_by", "created_at"],
        ["sort_order", "asc"],
      ])

      tickets = search_tickets(query)

      results = {
        count: tickets["results"].length,
        open: [],
        closed: [],
        solved: [],
        pending: [],
      }

      tickets["results"].each do |t|
        results[t["status"].to_sym] << t
      end

      puts "Unsolved: #{results[:count]}"
      puts "open: #{results[:open].length}"
      puts "pending: #{results[:pending].length}"

      tickets["results"].each do |t|
        puts "#{t["id"]}, #{t["status"]}, #{t["subject"]}"
      end
    end
  end

  module Metrics
    FIRST_REPLY_MINUTES_KPI = 60 * 24
    FIRST_REPLY_MINUTES_SLA = 60 * 24 * 2
    RESOLVE_MINUTES_KPI = 60 * 24 * 3

    def self.mean_and_std(array)
      squared_array = array.map { |t| t**2 }

      mean = array.sum(0.0) / array.length
      squared_mean = squared_array.sum(0.0) / squared_array.length

      standard_deviation = Math.sqrt(squared_mean - mean)

      { mean: mean, std: standard_deviation }
    end

    def self.calculate_first_reply_stats(metrics)
      replies_in_minutes = metrics.map do |m|
        m["ticket_metric"]["reply_time_in_minutes"]["business"]
      end.compact

      mean_and_std(replies_in_minutes)
    end

    def self.calculate_first_reply_max(metrics)
      metrics.map do |m|
        m["ticket_metric"]["reply_time_in_minutes"]["business"]
      end.compact.max
    end

    def self.calculate_first_resolve_stats(metrics)
      resolved_in_minutes = metrics.map do |m|
        m["ticket_metric"]["first_resolution_time_in_minutes"]["business"]
      end.compact

      mean_and_std(resolved_in_minutes)
    end

    def self.achieve_kpi?(max_reply_time)
      max_reply_time <= FIRST_REPLY_MINUTES_SLA
    end

    def self.display(metrics)
      reply_minutes = calculate_first_reply_stats(metrics)
      resolve_minutes = calculate_first_resolve_stats(metrics)
      max_time = calculate_first_reply_max(metrics)

      puts "初回返信KPI"
      puts "目標：#{FIRST_REPLY_MINUTES_KPI}分, 実績：#{reply_minutes.values.sum(0.0).ceil}分"
      puts
      puts "初回返信SLA"
      puts "SLA：#{FIRST_REPLY_MINUTES_SLA}分, 実績：#{max_time}分, 達成：#{achieve_kpi?(max_time)}"
      puts
      puts "初回解決KPI"
      puts "目標：#{RESOLVE_MINUTES_KPI}分, 実績：#{resolve_minutes.values.sum(0.0).ceil}分"

      puts
      puts "--------詳細-------"
      metrics.each do |m|
        id = m["ticket_metric"]["ticket_id"]
        reply = m["ticket_metric"]["reply_time_in_minutes"]["business"] || "-"
        resolve = m["ticket_metric"]["first_resolution_time_in_minutes"]["business"] || "-"
        printf "id:%5d, 初回返信：%4s分, 初回解決：%5s分\n", id, reply, resolve
      end
    end
  end

  module BusinessTime
    require "date"

    class << self
      def count_holidays(begin_time, end_time)
        begin_time = Date.parse(begin_time) unless begin_time.is_a?(Date)
        end_time = Date.parse(end_time) unless end_time.is_a?(Date)

        holidays = []

        begin_time.upto(end_time) do |d|
          holidays << d if HolidayJapan.check(d) || d.sunday? || d.saturday?
        end

        holidays.length
      end
    end
  end
end

reporter = Zendesk::Ticket.new

puts "--------Reported Dated--------------------"
puts "begin: #{reporter.begin_date}"
puts "end: #{reporter.end_date}"

puts "--------New tickets in this week----------"
tickets = reporter.get_new_in_thisweek
reporter.new_in_thisweek(tickets)

puts "--------Count of Unsolved tickets----------"
reporter.unsolved

puts "--------Solved tickets in this week----------"
reporter.solved_in_thisweek

puts "--------Metrics in this week----------"
Zendesk::Metrics.display(reporter.metrics(tickets))
