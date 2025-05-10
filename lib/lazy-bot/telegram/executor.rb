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

      puts "message.callback? = #{message.callback?}"
      puts "action_response.notice  = #{action_response.notice}"
      puts "action_response.alert = #{action_response.alert}"

      if !@ignore_callback && message.callback?
        actions << answer_callback_query_action
        return actions if !action_response.present?
      end

      return [] if !action_response.present?

      # Handle deletion of previous message if needed
      if action_response.present? && action_response.delete && message.present?
        actions << delete_message_action
      end

      # Handle clearing inline markup
      if action_response.clear_inline
        actions << clear_inline_markup_action
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

    def execute(actions = nil)
      actions ||= build_actions

      if actions.is_a?(Array)
        actions.each { run_action(it) }
      else
        run_action(action)
      end
    end

    def run_action(action)
      method = action.delete(:method)
      case method
      when 'sendMessage'
        send_text(args)
      when 'editMessageText'
        bot.api.edit_message_text(**action)
      when 'deleteMessage'
        bot.api.delete_message(**action)
      when 'answerCallbackQuery'
        bot.api.answer_callback_query(**action)
      when 'editMessageReplyMarkup'
        bot.api.edit_message_reply_markup(**action)
      when 'sendPhoto'
        # Handle local file upload if needed
        if action[:photo].is_a?(File) || action[:photo].is_a?(IO)
          action[:photo] = Faraday::UploadIO.new(action[:photo], 'image/jpeg')
        end
        bot.api.send_photo(**action)
      when 'sendMediaGroup'
        bot.api.send_media_group(**action)
      when 'sendDocument'
        # Handle local file upload if needed
        if action[:document].is_a?(File) || action[:document].is_a?(IO)
          action[:document] = Faraday::UploadIO.new(action[:document], 'application/octet-stream')
        end
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

      base_params = {
        method: 'sendPhoto',
        chat_id: context.chat_id,
        photo: final_photo,
        caption: action_response.text,
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

    def send_text(args)
      text = args[:text]
      if text.length >= 4000
        send_in_chunks(args)
      else
        bot.api.send_message(**args)
      end
    rescue StandardError => e
      if e.message.include?('can\'t parse entities')
        # Remove parse_mode and retry
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
