# frozen_string_literal: true

module LazyBot
  class DecoratedMessage < SimpleDelegator
    def initialize(obj, config)
      @config = config
      super(obj)
    end

    delegate :is_a?, to: :__getobj__

    def args(i)
      return @args[i] if defined?(@args)
      return nil if content.blank?

      @args = content.split
      @args[i]
    end

    def message_chat
      if inline_query?
        nil
      elsif callback?
        message.respond_to?(:chat) ?  message.chat : nil
      else
        chat
      end
    end

    def chat_id
      message_chat.id
    end

    # only for callback and text
    def content
      if respond_to?(:text)
        text
      elsif respond_to?(:data)
        data
      end
    end

    def callback?
      respond_to?(:data) && data.present?
    end

    def text_message?
      is_a?(Telegram::Bot::Types::Message) && text.present?
    end

    def inline_query?
      is_a?(Telegram::Bot::Types::InlineQuery)
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

    def voice?
      respond_to?(:voice) && voice.present?
    end

    def video?
      respond_to?(:video_note) && video_note.present?
    end

    def new_chat_members?
      respond_to?(:new_chat_members) && new_chat_members.present?
    end

    def left_chat_member?
      respond_to?(:left_chat_member) && left_chat_member.present?
    end

    def forward?
      respond_to?(:forward_origin) && forward_origin.present?
    end

    def reply_to_bot?
      respond_to?(:reply_to_message) && @config.bot_username == reply_to_message.from.username
      false
    end

    def reply_date
      return nil unless respond_to?(:reply_to_message)

      reply_to_message&.date
    end

    def supported?
      callback? || text_message? || document? || voice? || photo? ||  new_chat_members? || left_chat_member? || inline_query? || video?
    end

    def unsupported?
      return true if is_a?(Telegram::Bot::Types::ChatMemberUpdated)
      return true if in_channel?

      false
    end

    def mention?
      return false unless text_message?
      return false if text.blank?

      text.downcase.start_with?("@#{@config.bot_username.downcase}")
    end
  end
end
