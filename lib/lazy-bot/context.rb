# frozen_string_literal: true

module LazyBot
  class Context
    extend Forwardable
    attr_reader :bot, :message, :config, :repo

    def initialize(bot:, config:, message: nil, decorated_message: nil)
      @bot = bot
      @message = decorated_message || DecoratedMessage.new(message, config)
      @config = config
    end

    def build_repo
      config.repo_class.new(config:, bot:, message:)
    end

    def_delegators :@message, :chat_id, :message_id

    def chat
      @message.message_chat
    end
  end
end
