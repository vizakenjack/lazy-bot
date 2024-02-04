module LazyBot
  class DecoratedBotClient < SimpleDelegator
    def on_channel?(channel_id:, user_id:, default: false)
      result = api.get_chat_member(chat_id: channel_id, user_id:)

      ['member', 'administrator', 'creator'].include?(result.status)
    rescue StandardError
      default
    end

    def safe_delete_message(chat_id:, message_id:)
      api.delete_message(chat_id:, message_id:)
    rescue StandardError
      puts("Cant delete message with id: #{message_id}")
      nil
    end
  end
end
