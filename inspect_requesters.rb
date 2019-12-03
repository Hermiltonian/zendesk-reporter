require "bundler/setup"
require "holiday_japan"

module Zendesk
  require 'uri'
  require 'net/http'
  require "openssl"
  require "json"
  require "base64"
  require "csv"

  class Ticket
    attr_reader :email
    attr_reader :token
    attr_reader :begin_date
    attr_reader :end_date
    attr_reader :assignee
    attr_reader :users

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

      fetch_users

      #@begin_date = "2019-09-30T17:00:00+09:00"
      #@end_date = "2019-10-31T17:00:00+09:00"
      @begin_date = (Time.now - 3600 * 24 * 7).strftime("%FT17:00:00+09:00")
      @end_date = (Time.now).strftime("%FT17:00:00+09:00")
    end

    def fetch_users
      @assignee = { UnAssigned: [] }
      @users = {}

      begin
        CSV.foreach("./users.csv", headers: true, skip_blanks: true) do |row|
          next if row["id"].nil?
          @users.store(row["id"].to_s.to_sym, row["name"])
          @assignee.store(row["name"].to_sym, [])
        end
      rescue
        puts "ユーザー一覧ファイル'users.csv'を準備してください。"
        return
      end
    end

    def all(start_time = Time.new(2015,1,1,0,0,0), end_time = nil)
      if start_time.is_a?(Time)
        puts start_time
        start_time = start_time.to_i
      elsif !start_time.is_a?(Integer)
        return false
      end
      puts start_time

      url = URI.parse("https://sample.zendesk.com/api/v2/incremental/tickets.json?start_time=#{start_time}&end_time=#{end_time}")

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

      response = JSON.parse(response.body)
      tickets = response["tickets"]

      unless response['end_of_stream']
        next_start_time = response['next_page'].split('=').last.to_i
        next_end_time = response['end_time'].to_i
        tickets = tickets + all(next_start_time, next_end_time)
      end

      tickets
    end
  end
end

reporter = Zendesk::Ticket.new

# puts "--------New tickets in this week----------"
tickets = reporter.all
# tickets = reporter.all(Time.new(2017,11,20,0,0,0))
# tickets = reporter.all(Time.new(2019,11,20,0,0,0))

domains = tickets.map do |t|
  next unless t["via"]["channel"] == "email"

  t["via"]["source"]["from"]["address"].split('@').last
end.compact!

domains_counter = domains.inject({}) do |result, d|
  if result.has_key?(d)
    result[d] += 1
  else
    result[d] = 1
  end
  result
end

sorted_domains_counter = domains_counter.sort do |a, b|
  b[1] <=> a[1]
end.to_h

p tickets.map do |t|
  next unless t["via"]["channel"] == "email"
  t if t["via"]["source"]["from"]["address"].split('@').last == "google.com"
end

p sorted_domains_counter.to_json require 'json'
