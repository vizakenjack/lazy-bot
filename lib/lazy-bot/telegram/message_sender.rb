module LazyBot
  class MessageSender
    extend Forwardable

    attr_reader :chat_id, :context, :action_response

    def initialize(context, action_response)
      @context = context
      @action_response = action_response
    end

    def_delegators :@action_response, :text, :photo, :document, :parse_mode, :keyboard, :inline
    def_delegators :@context, :chat_id, :bot, :chat, :message

    def send
      MyLogger.debug "sending '#{text}' to #{chat&.username || chat_id} (#{chat_id})"
      delete_previous_message if action_response.delete && message.present?

      send_with_params
    rescue StandardError => e
      MyLogger.error "Can't send #{text} to user. Error: #{e.message}"
      raise e if ENV['BOT_ENV'] != 'production'

      nil
    end

    # only for callbacks
    def edit(skip_parse_mode: false)
      begin
        args = {
          chat_id:,
          message_id: message.message_id,
          parse_mode:,
          text:,
        }
        args[:reply_markup] = action_response.reply_markup if action_response.inline

        args.merge!(action_response.opts) if action_response.opts.present?

        args[:parse_mode] = nil if skip_parse_mode

        bot.api.edit_message_text(**args)
      rescue StandardError => e
        return edit(skip_parse_mode: true) if e.message.include?('can\'t parse entities')

        MyLogger.error "Can't send #{text} to user. Error: #{e.message}"
        return false
      end

      MyLogger.debug "Editing '#{text}' to #{chat&.username || chat_id} (#{chat_id})"
    end

    private

    def send_with_params
      args = {
        chat_id:,
        reply_markup: action_response.reply_markup,
        parse_mode:,
      }

      if message.respond_to?(:message_thread_id) && message.message_thread_id
        args[:reply_to_message_id] = message.message_thread_id
      end

      args.merge!(action_response.opts) if action_response.opts.present?

      if photo
        if photo.is_a?(Array) && photo.length > 1
          send_media_group(args)
        else
          args[:caption] = text
          send_photo_with_caption(args)
        end
      elsif document
        args[:caption] = text
        send_document_with_caption(args)
      else
        args[:text] = text
        send_text(args)
      end
    end

    def send_photo_with_caption(args)
      final_photo = photo.is_a?(Array) && photo.length == 1 ? photo.first : photo
      photo_type = final_photo.is_a?(String) && final_photo.end_with?('.png') ? 'image/png' : 'image/jpeg'
      photo_content = build_upload(final_photo, type: action_response.mime || photo_type)
      args.merge!({ photo: photo_content })

      bot.api.send_photo(**args)
    end

    def send_media_group(args)
      media_group = photo.each_with_index.map do |photo, _index|
        {
          type: 'photo',
          media: photo,
        }
      end

      args.merge!({ media: media_group })

      bot.api.send_media_group(**args)
    end

    def send_document_with_caption(args)
      document_data = {
        document: build_upload(document, type: action_response.mime || 'image/jpeg'),
      }
      args.merge!(document_data)

      bot.api.send_document(**args)
    end

    def send_text(args)
      if text.length >= 4000
        send_in_chunks(args)
      else
        bot.api.send_message(**args)
      end
    rescue StandardError => e
      send_text(**args.merge(parse_mode: nil)) if e.message.include?('can\'t parse entities')
    end

    def send_in_chunks(args, chunk_size = 4000)
      text.chars.each_slice(chunk_size) do |chunk|
        bot.api.send_message(**args.merge(text: chunk.join))
      end
    end

    def build_upload(file_or_url, type)
      if file_or_url.is_a?(String) && file_or_url.start_with?('http')
        file_or_url
      else
        Faraday::UploadIO.new(file_or_url, type)
      end
    end

    def delete_previous_message
      @bot.api.delete_message(chat_id: chat_id, message_id: message.message_id)
    rescue StandardError
      MyLogger.error "Cant delete #{message.message_id}, with new text: #{action_response.text}"
    end
  end
end
