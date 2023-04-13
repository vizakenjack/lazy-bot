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

    # def menu_button(text)
    #   Telegram::Bot::Types::MenuButtonCommands.new(type: text)
    # end
  end
end
