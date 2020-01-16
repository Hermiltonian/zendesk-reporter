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

    def initialize(begin_date, end_date)
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

      @begin_date = begin_date || Time.new(2015,1,1,0,0,0, "+09:00")
      @end_date = end_date || Time.now.localtime("+09:00")
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

    def to_time_int(time)
      if time.is_a?(String)
        require "date"
        time = DateTime.parse(time).to_time
      elsif !time.is_a?(Time) && !start_time.is_a?(Integer)
        return false
      end

      time.to_i
    end

    def all
      puts @begin_date
      url = URI.parse("https://sample.zendesk.com/api/v2/incremental/tickets.json?start_time=#{to_time_int(@begin_date)}&end_time=#{to_time_int(@end_date)}")

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

    def allAsHTML
      tickets = self.all

      require "cgi/escape"

      html = <<~EOT
      <!DOCTYPE html>
      <html lang="ja">
        <head>
          <meta charset="utf-8">
          <link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.4.1/css/bootstrap.min.css" integrity="sha384-Vkoo8x4CGsO3+Hhxv8T/Q5PaXtkKtu6ug5TOeNV6gBiFeWPGFN9MuhOf23Q9Ifjh" crossorigin="anonymous">
        </head>
        <body>
          <div class="container-fluid">
            <div class="row">
              <table class="table">
                <thead class="thead-dark">
                  <tr>
                    <th>id</th>
                    <th>問い合わせ日時</th>
                    <th>リクエスタ</th>
                    <th>タイトル</th>
                    <th>詳細</th>
                  </tr>
                </thead>
                <tbody>
      EOT

      modal = ""

      tickets.each do |t|
        html += <<~EOT
          <tr>
            <td>#{t['id']}</td>
            <td>#{t['created_at']}</td>
        EOT

        if t["via"]["channel"] == "email"
          html += <<~EOT
            <td>#{t["via"]["source"]["from"]["address"]}</td>
          EOT
        else
          html += <<~EOT
            <td>#{t["via"]["channel"]}</td>
          EOT
        end

        html += <<~EOT
            <td>#{t['subject']}</td>
            <td><button type="type" class="btn btn-primary" data-toggle="modal" data-target="#modal-#{t['id']}">詳細</button></td>
          </tr>
        EOT

        modal += <<~EOT
          <div class="modal" id="modal-#{t['id']}" tabindex="-1" role="dialog" aria-labelledby="label-#{t['id']}" aria-hidden="true">
            <div class="modal-dialog modal-dialog-centered modal-xl" role="document">
              <div class="modal-content">
                <div class="modal-header">
                  <h5 class="modal-title" id="label-#{t['id']}">#{t['subject']}</h5>
                  <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true">&times;</span>
                  </button>
                </div>
                <div class="modal-body">
                  #{CGI.escapeHTML(t['description'].gsub(/\n/, "__special_linebreak__")).gsub(/__special_linebreak__/, "<br>")}
                </div>
                <div class="modal-footer">
                  <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
                </div>
              </div>
            </div>
          </div>
        EOT
      end

      html += <<~EOT
                </tbody>
              </table>
            </div>
          </div>
          <div>
            #{modal}
          </div>
          <script src="https://code.jquery.com/jquery-3.4.1.slim.min.js" integrity="sha384-J6qa4849blE2+poT4WnyKhv5vZF5SrPo0iEjwBvKU7imGFAV0wwj1yYfoRSJoZ+n" crossorigin="anonymous"></script>
          <script src="https://cdn.jsdelivr.net/npm/popper.js@1.16.0/dist/umd/popper.min.js" integrity="sha384-Q6E9RHvbIyZFJoft+2mJbHaEWldlvI9IOYy5n3zV9zzTtmI3UksdQRVvoxMfooAo" crossorigin="anonymous"></script>
          <script src="https://stackpath.bootstrapcdn.com/bootstrap/4.4.1/js/bootstrap.min.js" integrity="sha384-wfSDF2E50Y2D1uUdj0O3uMBJnjuUD4Ih7YwaYd1iqfktj0Uod8GCExl3Og8ifwB6" crossorigin="anonymous"></script>
        </body>
      </html>
      EOT

      File.open("issues.html", "w") do |f|
        f.print html
      end
    end

    def allAsCSV
      tickets = self.all

      require 'csv'
      headers = [
        "id",
        "created_at",
        "requester",
        "subject",
        "description",
      ]
      csv = CSV::Table.new([CSV::Row.new(headers, [])])
      tickets.each do |t|
        row = [
          t['id'],
          t['created_at'],
        ]

        row << if t["via"]["channel"] == "email"
          t["via"]["source"]["from"]["address"]
        else
          t["via"]["channel"]
        end

        row << t['subject']
        row << t['description']

        csv << CSV::Row.new(headers, row)
      end

      require "kconv"
      File.open("issues.csv", "w") do |f|
        f.print csv.to_csv.tosjis
      end
    end

    def requesterDomains
      tickets = self.all

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
    end
  end
end

require "date"
begin_date = ARGV[1].nil? ? nil : DateTime.parse("#{ARGV[1]}+09:00").to_s
end_date = ARGV[2].nil? ? nil : DateTime.parse("#{ARGV[1]}+09:00").to_s

reporter = Zendesk::Ticket.new(begin_date, end_date)

case ARGV[0]
when "html"
  reporter.allAsHTML
when "csv"
  reporter.allAsCSV
when "domain"
  reporter.requesterDomains
end
