require 'sinatra'
require 'time'
require 'uri'
require 'open-uri'
require 'cgi'
require 'fluidinfo'
require 'rack/cors'

disable :protection

use Rack::Cors do |config|
  config.allow do |allow|
    allow.origins '*'
    allow.resource '*', :headers => :any, :methods => [:get, :post, :options]
  end
end

before '/hm/*' do
  @hmurl = "http://example.com/hm/" # CHANGE it to your HTTP Mailbox URL!
  @fi_user = "YOUR-FLUIDINFO-USERID" # CHANGE it!
  @fi_pass = "YOUR-FLUIDINFO-PASSWORD" # CHANGE it!
  @basens = "#{@fi_user}/hm/"
  @recipient = params[:splat].first
  @recipient += "?" + request.query_string unless request.query_string.empty?
  @sender = request.referrer
  @sender = request.env['HTTP_SENDER'] if request.env['HTTP_SENDER']
  @client = request.ip
  @recipient = CGI.unescape @recipient

  @fi = Fluidinfo::Client.new :user => @fi_user, :password => @fi_pass

  headers "Server" => "HTTP Mailbox",
          "Content-type" => "message/http"
end

get '/hm/*' do
  r = /^id\/([\da-f]{8}-[\da-f]{4}-[\da-f]{4}-[\da-f]{4}-[\da-f]{12})$/
  m = r.match @recipient
  if m
    @guid = m[1]
  else
    last = @fi.get "/about/#{CGI.escape @recipient}/#{@basens}last"
    @guid = last.value if last.status == 200
  end
  if @guid
    res = @fi.get "/values",
                  :query => "fluiddb/id = \"#{@guid}\"",
                  :tags  => ["#{@basens}sender",
                             "#{@basens}recipient",
                             "#{@basens}msgbody",
                             "#{@basens}mementodatetime",
                             "#{@basens}client",
                             "#{@basens}previous",
                             "#{@basens}next"]
    obj = res.value["results"]["id"].first
    if obj
      msg = obj[1]["#{@basens}msgbody"]
      msg["guid"] = obj[0]
      msg["sender"] = obj[1]["#{@basens}sender"]["value"] unless obj[1]["#{@basens}sender"].nil?
      msg["recipient"] = obj[1]["#{@basens}recipient"]["value"] unless obj[1]["#{@basens}recipient"].nil?
      msg["mementodatetime"] = obj[1]["#{@basens}mementodatetime"]["value"] unless obj[1]["#{@basens}mementodatetime"].nil?
      msg["client"] = obj[1]["#{@basens}client"]["value"] unless obj[1]["#{@basens}client"].nil?
      msg["previous"] = obj[1]["#{@basens}previous"]["value"] unless obj[1]["#{@basens}previous"].nil?
      msg["next"] = obj[1]["#{@basens}next"]["value"] unless obj[1]["#{@basens}next"].nil?
      msg["previous"] = nil if msg["previous"] == "FIRST"
      msg["next"] = nil if msg["next"] == "LAST"

      first = @fi.get "/about/#{CGI.escape msg["recipient"]}/#{@basens}first"
      @first = first.value if first.status == 200
      last = @fi.get "/about/#{CGI.escape msg["recipient"]}/#{@basens}last"
      @last = last.value if last.status == 200

      cp = "<#{@msurl + msg["recipient"].gsub(" ", "+")}>; rel=\"current\""
      sp = "<#{@msurl}id/#{@guid}>; rel=\"self\""
      fp = "<#{@msurl}id/#{@first}>; rel=\"first\"" unless @first.nil?
      lp = "<#{@msurl}id/#{@last}>; rel=\"last\"" unless @last.nil?
      np = "<#{@msurl}id/#{msg["next"]}>; rel=\"next\"" unless msg["next"].nil?
      pp = "<#{@msurl}id/#{msg["previous"]}>; rel=\"previous\"" unless msg["previous"].nil?

      links = [cp, sp, fp, lp, np, pp].compact.join(", ")

      headers "Date" => Time.now.httpdate,
              "Memento-Datetime" => msg["mementodatetime"],
              "Via" => "sent by #{msg["client"]} on behalf of #{msg["sender"]}, delivered by #{@hmurl}",
              "Link" => links

      body msg["value"]
    else
      status 404
    end
  else
    status 404
  end
end

post '/hm/*' do
  rb = URI.unescape request.body.read

  s_flag = false
  o = @fi.post "/objects"
  if o.status == 201
    last = @fi.get "/about/#{CGI.escape @recipient}/#{@basens}last"
    if last.status == 200
      @previous = last.value
      upd = @fi.put "/values",
                    :body => {:queries => [["fluiddb/id = \"#{@previous}\"",
                                            {"#{@basens}next" => {:value => o.value["id"]}}]]}
    else
      @previous = "FIRST"
      first = @fi.put "/about/#{CGI.escape @recipient}/#{@basens}first", :body => o.value["id"]
    end
    last = @fi.put "/about/#{CGI.escape @recipient}/#{@basens}last", :body => o.value["id"]

    upd = @fi.put "/values",
                  :body => {:queries => [["fluiddb/id = \"#{o.value["id"]}\"",
                                          {"#{@basens}sender" => {:value => @sender},
                                           "#{@basens}recipient" => {:value => @recipient},
                                           "#{@basens}msgbody" => {:value => rb},
                                           "#{@basens}mementodatetime" => {:value => Time.now.httpdate},
                                           "#{@basens}client" => {:value => @client},
                                           "#{@basens}previous" => {:value => @previous},
                                           "#{@basens}next" => {:value => "LAST"}}]]}

    s_flag = true if upd.status == 204
  end

  if s_flag
    status 201
    headers "Location" => @hmurl + "id/" + o.value["id"]
  else
    status 500
  end

  body nil
end

get '/' do
  "HTTP Mailbox endpoint is at '/hm/' and it supports GET and POST HTTP methods with CORS supprt."
end

options '/*' do |r|
  # To allow complex CORS
end
