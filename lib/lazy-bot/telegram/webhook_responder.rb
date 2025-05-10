# frozen_string_literal: true

module LazyBot
  class WebhookResponder
    attr_reader :context, :action_response

    def initialize(context, action_response)
      @context = context
      @action_response = action_response
    end

    def_delegators :@context, :chat, :message

    def build_actions
      actions = []

      if message.callback?
        actions << answer_callback_query_action
      end

      # Handle deletion of previous message if needed
      if action_response.present? && action_response.delete && message.present?
        actions << delete_message_action
      end

      # Handle clearing inline markup
      if action_response.clear_inline
        actions << clear_inline_markup_action
      end

      # Handle callback query answer if needed
      if message.respond_to?(:id) && (action_response.notice || action_response.edit || action_response.text)
        actions << answer_callback_query_action
      end

      # Handle inline markup updates
      if action_response.inline && action_response.text.blank?
        actions << edit_inline_markup_action
      end

      # Handle primary action (text, photo, document, etc)
      if action_response.photo
        if action_response.photo.is_a?(Array) && action_response.photo.length > 1
          actions << send_media_group_action
        else
          actions << send_photo_action
        end
      elsif action_response.document
        actions << send_document_action
      elsif action_response.text
        if action_response.edit
          actions << edit_text_action
        else
          actions << send_text_action
        end
      end

      actions
    end

    def execute
      actions = build_actions
      last_action = actions.pop

      if actions.any?
        Async do
          puts "After 5, executing actions"
          sleep 5
          actions.each do |action|
            puts "Executing #{action}"
            context.bot.call(action[:method], action)
          end
        end
      end

      puts "Executing #{action}"

      last_action
    end

    private

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

    def delete_message_action
      {
        method: 'deleteMessage',
        chat_id: context.chat_id,
        message_id: message.message_id,
      }
    end

    def clear_inline_markup_action
      {
        method: 'editMessageReplyMarkup',
        chat_id: context.chat_id,
        message_id: message.message_id,
        reply_markup: { inline_keyboard: [] },
      }
    end

    def answer_callback_query_action
      action = {
        method: 'answerCallbackQuery',
        callback_query_id: message.id,
      }

      if action_response.notice
        action[:text] = action_response.notice
        action[:show_alert] = action_response.alert
      end

      action
    end

    def send_text_action
      base_params = {
        method: 'sendMessage',
        chat_id: context.chat_id,
        text: action_response.text,
        parse_mode: action_response.parse_mode,
        **action_response.opts,
      }

      if action_response.reply_markup
        base_params[:reply_markup] = action_response.reply_markup
      end

      if message.respond_to?(:message_thread_id) && message.message_thread_id
        base_params[:reply_to_message_id] = message.message_thread_id
      end

      base_params.merge(action_response.opts || {})
    end

    def edit_text_action
      base_params = {
        method: 'editMessageText',
        chat_id: context.chat_id,
        message_id: message.message_id,
        text: action_response.text,
        parse_mode: action_response.parse_mode,
        **action_response.opts,
      }

      if action_response.inline
        base_params[:reply_markup] = action_response.reply_markup
      end

      base_params
    end

    def send_photo_action
      final_photo = action_response.photo.is_a?(Array) ? action_response.photo.first : action_response.photo

      base_params = {
        method: 'sendPhoto',
        chat_id: context.chat_id,
        photo: final_photo,
        caption: action_response.text,
        parse_mode: action_response.parse_mode,
        **action_response.opts,
      }

      if action_response.reply_markup
        base_params[:reply_markup] = action_response.reply_markup
      end

      base_params
    end

    def send_media_group_action
      media = action_response.photo.map do |photo|
        {
          type: 'photo',
          media: photo,
        }
      end

      {
        method: 'sendMediaGroup',
        chat_id: context.chat_id,
        media: media,
        **action_response.opts,
      }
    end

    def send_document_action
      {
        method: 'sendDocument',
        chat_id: context.chat_id,
        document: action_response.document,
        caption: action_response.text,
        parse_mode: action_response.parse_mode,
        reply_markup: action_response.reply_markup,
        **action_response.opts,
      }
    end

    def edit_inline_markup_action
      {
        method: 'editMessageReplyMarkup',
        chat_id: context.chat_id,
        message_id: message.message_id,
        reply_markup: action_response.reply_markup,
      }
    end
  end
end

# module LazyBot
#   class WebhookResponder
#     extend Forwardable

#     attr_reader :context, :action_response, :json

#     def initialize(context, action_response)
#       @context = context
#       @action_response = action_response
#     end

#     def call
#       @json = as_json
#     end

#     def respond
#     end

#     # def_delegators :@action_response, :text, :notice, :photo, :document
#     def_delegators :@context, :bot, :chat, :message

#     def as_json
#       if notice
#         @json = {
#           method: make_method,
#           callback_query_id: message.id,
#           text: action_response.notice,
#           show_alert: action_response.alert,
#         }
#         return @json
#       end

#       @json = {
#         method: make_method,
#         chat_id: context.chat_id,
#         text: action_response.text,
#         **action_response.opts,
#       }

#       if action_response.edit_inline || action_response.clear_inline || action_response.edit
#         @json[:message_id] = context.message_id
#       end

#       if message.respond_to?(:message_thread_id) && message.message_thread_id
#         @json[:reply_to_message_id] = message.message_thread_id
#       end

#       @json[:reply_markup] = action_response.reply_markup if action_response.inline
#       @json[:parse_mode] = action_response.parse_mode if action_response.parse_mode
#       @json
#     end

#     def make_method
#       if action_response.edit_inline || action_response.clear_inline
#         'editMessageReplyMarkup'
#       elsif action_response.edit
#         'editMessageText'
#       elsif action_response.notice
#         'answerCallbackQuery'
#       else
#         'sendMessage'
#       end
#     end
#   end
# end
