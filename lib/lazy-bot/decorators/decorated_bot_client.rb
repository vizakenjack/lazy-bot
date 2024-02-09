module LazyBot
  class DecoratedBotClient < SimpleDelegator

    def reply_to(message, text: , **args)
      args[:chat_id] = message.chat.id
      args[:text] = text
      args[:reply_to_message_id] = message.message_thread_id if message.respond_to?(:message_thread_id) && message.message_thread_id
      api.send_messsage(**args)
    # rescue StandardError
      # puts("Cant send message with args: #{args}")
      # nil
    end

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
