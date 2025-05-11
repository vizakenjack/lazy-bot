module LazyBot
  class Executor
    extend Forwardable

    attr_reader :context, :action_response

    def initialize(context, action_response, **opts)
      @context = context
      @action_response = action_response
      @ignore_callback = opts[:ignore_callback] || false
    end

    def_delegators :@context, :bot, :chat, :message

    def build_actions
      actions = []

      if !@ignore_callback && message.callback?
        actions << answer_callback_query_action
        return actions if !action_response.present?
      end

      return [] unless action_response.present?

      actions << delete_message_action if action_response.delete && message.present?
      actions << clear_inline_markup_action if action_response.clear_inline
      actions << edit_inline_markup_action if action_response.inline && action_response.text.blank?

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
          text_actions = build_send_text_actions
          actions.concat(text_actions)
          actions << { method: 'empty' } if text_actions.length >= 2
        end
      end

      actions
    end

    def execute(actions = nil)
      actions ||= build_actions

      if actions.is_a?(Array)
        actions.each { |it| run_action(it) }
      else
        run_action(actions)
      end
    end

    def run_action(action)
      method = action.delete(:method)
      case method
      when 'empty'
        # nothing
      when 'sendMessage'
        send_text(action)
      when 'editMessageText'
        bot.api.edit_message_text(**action)
      when 'deleteMessage'
        bot.api.delete_message(**action)
      when 'answerCallbackQuery'
        bot.api.answer_callback_query(**action)
      when 'editMessageReplyMarkup'
        bot.api.edit_message_reply_markup(**action)
      when 'sendPhoto'
        action[:photo] = build_upload(action[:photo], action_response.mime || 'image/jpeg')
        bot.api.send_photo(**action)
      when 'sendMediaGroup'
        action[:media] = action[:media].map do |media_item|
          media_item = media_item.dup
          media_item[:media] = build_upload(media_item[:media], action_response.mime || 'image/jpeg')
          media_item
        end
        bot.api.send_media_group(**action)
      when 'sendDocument'
        action[:document] = build_upload(action[:document], action_response.mime || 'application/octet-stream')
        bot.api.send_document(**action)
      else
        MyLogger.warn "Unknown action method: #{method}"
      end
    rescue Telegram::Bot::Exceptions::ResponseError => e
      MyLogger.error "Telegram API error for #{method}: #{e.message}, params: #{action.inspect}"
    rescue StandardError => e
      MyLogger.error "Executor error in #{method}: #{e.message}, params: #{action.inspect}"
    end

    private

    def build_upload(file_or_url, type)
      if file_or_url.is_a?(String) && file_or_url.start_with?('http')
        file_or_url
      else
        Faraday::UploadIO.new(file_or_url, type)
      end
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

    def build_send_text_actions
      text = action_response.text
      return [send_text_action(text)] if text.length < 4000

      chunks = text.chars.each_slice(4000).map(&:join)
      chunks.map { |chunk| send_text_action(chunk) }
    end

    def send_text_action(text)
      base_params = {
        method: 'sendMessage',
        chat_id: context.chat_id,
        text: text,
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
        **action_response.opts,
      }

      if action_response.inline
        base_params[:reply_markup] = action_response.reply_markup
      end

      base_params
    end

    def send_photo_action
      final_photo = action_response.photo.is_a?(Array) ? action_response.photo.first : action_response.photo
      {
        method: 'sendPhoto',
        chat_id: context.chat_id,
        photo: final_photo,
        caption: action_response.text,
        **action_response.opts,
      }
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

    def send_text(args)
      text = args[:text]
      if text.length >= 4000
        send_in_chunks(args)
      else
        bot.api.send_message(**args)
      end
    rescue StandardError => e
      if e.message.include?("can't parse entities")
        args = args.merge(parse_mode: nil)
        bot.api.send_message(**args)
      else
        raise
      end
    end

    def send_in_chunks(args, chunk_size = 4000)
      text = args[:text]
      text.chars.each_slice(chunk_size) do |chunk|
        bot.api.send_message(**args.merge(text: chunk.join))
      end
    end
  end
end
