# frozen_string_literal: true

module LazyBot
  class WebhookResponder
    extend Forwardable

    attr_reader :context, :action_response, :json

    def initialize(context, action_response)
      @context = context
      @action_response = action_response
    end

    def call
      @json = as_json
    end

    def respond
    end

    # def_delegators :@action_response, :text, :notice, :photo, :document
    def_delegators :@context, :bot, :chat, :message

    def as_json
      if notice
        @json = {
          method: make_method,
          callback_query_id: message.id,
          text: action_response.notice,
          show_alert: action_response.alert,
        }
        return @json
      end

      @json = {
        method: make_method,
        chat_id: context.chat_id,
        text: action_response.text,
        **action_response.opts,
      }

      if action_response.edit_inline || action_response.clear_inline || action_response.edit
        @json[:message_id] = context.message_id
      end

      if message.respond_to?(:message_thread_id) && message.message_thread_id
        @json[:reply_to_message_id] = message.message_thread_id
      end

      @json[:reply_markup] = action_response.reply_markup if action_response.inline
      @json[:parse_mode] = action_response.parse_mode if action_response.parse_mode
      @json
    end

    def make_method
      if action_response.edit_inline || action_response.clear_inline
        'editMessageReplyMarkup'
      elsif action_response.edit
        'editMessageText'
      elsif action_response.notice
        'answerCallbackQuery'
      else
        'sendMessage'
      end
    end
  end
end
