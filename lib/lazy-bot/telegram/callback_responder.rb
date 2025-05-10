# frozen_string_literal: true

module LazyBot
  class CallbackResponder
    extend Forwardable

    attr_reader :context, :callback, :message, :action_response

    def initialize(context, action_response)
      @context = context
      @callback = context.message
      @action_response = action_response
    end

    def_delegators :@action_response, :text, :notice, :photo, :document
    def_delegators :@context, :bot, :chat, :message

    def send
      delete_previous_message if action_response.present? && action_response.delete && message.present?
      clear_inline_markup if action_response.clear_inline

      if text
        if action_response.edit
          edit_message
          return
        else
          answer_with_message
        end
      elsif notice
        answer_with_notice notice
      elsif photo || document
        answer_with_message
      elsif DEVELOPMENT
        puts "No action found for callback: #{callback.data}"
      end

      return unless action_response.inline && action_response.text.blank?

      edit_inline_markup
    end

    private

    def delete_previous_message
      puts "Deleting previous message: #{message.to_h}" if DEVELOPMENT
      @bot.api.delete_message(chat_id: chat.id, message_id: message.message_id)
    rescue StandardError
      MyLogger.error "Cant delete #{message.message_id}, with new text: #{action_response.text}"
    end

    def answer_with_notice(notice)
      @bot.api.answer_callback_query(callback_query_id: callback.id, text: notice, show_alert: action_response.alert)
    rescue Telegram::Bot::Exceptions::ResponseError
      MyLogger.error 'Cant answer callback query: delete_previous_message'
    end

    def answer_with_message
      MessageSender.new(context, action_response).send

      @bot.api.answer_callback_query(callback_query_id: callback.id)
    rescue Telegram::Bot::Exceptions::ResponseError
      MyLogger.error 'Cant answer callback query: answer_with_message'
    end

    def edit_message
      MessageSender.new(context, action_response).edit

      @bot.api.answer_callback_query(callback_query_id: callback.id)
    rescue StandardError
      MyLogger.error 'Cant answer callback query: edit_message'
    end

    def clear_inline_markup
      args = {
        chat_id: message.chat.id,
        message_id: message.message_id,
        reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: []),
      }

      bot.api.edit_message_reply_markup(**args)
    rescue StandardError
      MyLogger.error 'Cant answer callback query: clear_inline_markup'
    end

    def edit_inline_markup
      args = {
        chat_id: message.chat.id,
        message_id: message.message_id,
        reply_markup: action_response.reply_markup,
      }
      bot.api.edit_message_reply_markup(**args)
    rescue StandardError
      MyLogger.error 'Cant answer callback query: edit_inline_markup'
    end
  end
end
