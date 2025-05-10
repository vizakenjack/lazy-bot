# frozen_string_literal: true

module LazyBot
  class Context
    extend Forwardable
    attr_reader :bot, :message, :config, :repo

    def initialize(bot:, message:, config:)
      @bot = bot
      @message = message # already decorated
      @config = config
    end

    def build_repo
      config.repo_class.new(config:, bot:, message:)
    end

    def_delegators :@message, :chat_id

    def chat
      @message.message_chat
    end
  end
end