# frozen_string_literal: true

require "sinatra"
require "sinatra/cross_origin"

module LazyBot
  class SinatraApp < Sinatra::Base
    set :bind, LazyBot.сonfig.socket_path

    configure do
      enable :cross_origin
    end

    before do
      response.headers["Access-Control-Allow-Origin"] = "*"
    end

    options "*" do
      response.headers["Allow"] = "GET, PUT, POST, DELETE, OPTIONS"
      response.headers["Access-Control-Allow-Headers"] =
        "Authorization, Content-Type, Accept, X-User-Email, X-Auth-Token"
      response.headers["Access-Control-Allow-Origin"] = "*"
      200
    end

    get "/" do
      "ok"
    end

    post "/" do
      request.body.rewind
      data = JSON.parse(request.body.read)

      update_id = data["update_id"]

      puts 'Received request' if LazyBot.сonfig.debug_mode

      if new_request?(update_id)
        @last_update_id = update_id
        message = Telegram::Bot::Types::Update.new(data).current_message

        BOT.respond_message(message)
      elsif LazyBot.сonfig.debug_mode
        puts "Sinatra: skipping same request #{data}"
      end
    rescue Exception => e
      LazyBot.сonfig.on_error(e)
      MyLogger.sinatra.error "Sinatra error #{e}"
    ensure
      status 200
    end

    # def new_request?(_update_id)
    #   true
    # end

    def new_request?(update_id)
      MyLogger.sinatra.info "Sinatra update_id: #{update_id}, current_id is #{@last_update_id}"
      return true if @last_update_id.nil? || update_id.nil? || update_id == 0

      update_id > @last_update_id
    end
  end
end
