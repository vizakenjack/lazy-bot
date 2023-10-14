# frozen_string_literal: true

require 'delegate'

module LazyBot
  class DecoratedBotClient < SimpleDelegator
    def on_channel?(channel_id:, user_id:)
      result = api.get_chat_member(chat_id: channel_id, user_id:)
      return false unless result['ok']

      status = result.dig('result', 'status')
      ['member', 'administrator', 'creator'].include?(status)
    rescue Exception # rubocop:disable Lint/RescueException
      false
    end

    def safe_delete_message(chat_id:, message_id:)
      api.delete_message(chat_id:, message_id:)
    rescue StandardError
      puts("Cant delete message with id: #{message_id}")
      nil
    end

    # def menu_button(text)
    #   Telegram::Bot::Types::MenuButtonCommands.new(type: text)
    # end
  end
end
