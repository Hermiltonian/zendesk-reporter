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

    file.close

    @begin_date = (Time.now - 3600 * 24 * 7).strftime("%FT17:00:00+09:00")
    @end_date = (Time.now).strftime("%FT17:00:00+09:00")
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

    raise RuntimeError unless response.is_a?(Net::HTTPSuccess)
    tickets = JSON.parse(response.body)
    tickets["results"].delete_if { |t| t["status"].nil? }

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
