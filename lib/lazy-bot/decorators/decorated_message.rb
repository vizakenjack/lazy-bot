# frozen_string_literal: true

require 'delegate'

module LazyBot
  class DecoratedMessage < SimpleDelegator
    delegate :is_a?, to: :__getobj__

    def initialize(obj, config)
      @config = config
      super(obj)
    end

    def args(i)
      return nil if content.blank?

      begin
        content.split[i]
      rescue StandardError => e
        MyLogger.error("Splitting #{content} - Got error #{e.inspect}")
        nil
      end
    end

    def content
      if respond_to?(:text)
        text
      elsif respond_to?(:data)
        data
      end
    end

    def callback?
      !respond_to?(:chat) && data.present?
    end

    def text_message?
      is_a?(Telegram::Bot::Types::Message) && text.present?
    end

    def in_group?
      respond_to?(:chat) && (chat&.type == 'group' || chat&.type == 'supergroup')
    end

    def in_channel?
      respond_to?(:sender_chat) && sender_chat&.type == 'channel'
    end

    def document?
      respond_to?(:document) && document.present?
    end

    def photo?
      respond_to?(:photo) && photo.present?
    end

    def forward?
      (respond_to?(:forward_from) && forward_from.present?) ||
        (respond_to?(:forward_sender_name) && forward_sender_name.present?)
    end

    def reply_to_bot?
      respond_to?(:reply_to_message) && @config.bot_username == reply_to_message.from.username
      false
    end

    def reply_date
      reply_to_message&.date
    end

    def to_params(params = {})
      params ||= {}

      params.merge!({ telegram_id: from.id, name: from.first_name })

      params.tap do |p|
        p[:telegram_username] = from.username if from.username
        p[:bot] = ENV['BOT_ROLE']
      end
    end

    def unsupported?
      return true if is_a?(Telegram::Bot::Types::ChatMemberUpdated)
      return true if in_group? && mention? == false
      return true if in_channel?

      false
    end

    def mention?
      return false if text.blank?

      text.downcase.start_with?("@#{@config.bot_username.downcase}")
    end
  end
end
