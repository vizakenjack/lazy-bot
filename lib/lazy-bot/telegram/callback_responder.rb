# frozen_string_literal: true

module LazyBot
  class CallbackResponder
    attr_reader :callback, :message, :chat, :bot, :action_response

    def initialize(params)
      @bot = params[:bot]
      @callback = params[:message]
      @message = @callback.message
      @action_response = params[:action_response]
      @chat = @message.chat
    end

    delegate :text, to: :action_response
    delegate :notice, to: :action_response

    def send
      delete_previous_message if action_response.replace

      if text
        if action_response.edit
          edit_message
          return
        else
          answer_with_message
        end
      elsif notice
        answer_with_notice notice
      end

      if action_response.inline && action_response.text.blank?
        edit_inline_markup
      elsif action_response.clear_inline
        clear_inline_markup
      end
    end

    private

    def delete_previous_message
      @bot.api.delete_message(chat_id: chat.id, message_id: message.message_id)
    rescue Exception => e # rubocop:disable Lint/RescueException
      MyLogger.error "Cant delete #{message.message_id}, with new text: #{action_response.text}"
    end

    def answer_with_notice(notice)
      @bot.api.answer_callback_query(callback_query_id: callback.id, text: notice, show_alert: action_response.alert)
    rescue Telegram::Bot::Exceptions::ResponseError
      MyLogger.error "Cant answer callback query"
    end

    def answer_with_message
      args = {
        bot:,
        chat:,
        action_response:,
      }

      MessageSender.new(**args).send

      @bot.api.answer_callback_query(callback_query_id: callback.id)
    rescue Telegram::Bot::Exceptions::ResponseError
      MyLogger.error "Cant answer callback query"
    end

    def edit_message
      args = {
        bot:,
        chat:,
        action_response:,
        message:,
      }

      MessageSender.new(**args).edit

      @bot.api.answer_callback_query(callback_query_id: callback.id)
    rescue StandardError => e
      MyLogger.error "Cant answer callback query"
    end

    def clear_inline_markup
      args = {
        chat_id: message.chat.id,
        message_id: message.message_id,
        reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: []),
      }
      bot.api.edit_message_reply_markup(**args)
    end

    def edit_inline_markup
      args = {
        chat_id: message.chat.id,
        message_id: message.message_id,
        reply_markup: action_response.reply_markup,
      }
      bot.api.edit_message_reply_markup(**args)
    end
  end
end
