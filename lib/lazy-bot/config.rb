# frozen_string_literal: true

module LazyBot
  class Config
    attr_reader :timeout, :telegram_token, :bot_names, :debug_mode, :socket_path, :default_action_opts

    def initialize(**args)
      @timeout = args[:timeout] || 120
      @bot_names = args[:bot_names] || []
      @debug_mode = args[:debug_mode]
      @socket_path = File.expand_path(args[:socket_path] || "../../shared/tmp/chatbot.sock")
      @telegram_token = args[:telegram_token]
      @on_error = args[:on_error]
      @default_action_opts = args[:default_action_opts] || {}
    end

    def on_error(error)
      @on_error&.call(error)
    end
  end
end
