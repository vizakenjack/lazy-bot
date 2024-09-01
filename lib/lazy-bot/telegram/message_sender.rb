# frozen_string_literal: true

module LazyBot
  class MessageSender
    extend Forwardable

    attr_reader :bot, :chat, :chat_id, :action_response, :message

    def initialize(params)
      @bot = params[:bot]
      @chat = params[:chat]
      # todo: remove params[:id]
      @chat_id = params[:chat]&.id || params[:id] || params[:chat_id] || params[:message]&.chat&.id
      @action_response = build_action_response(params)
      @message = params[:message]
    end

    def_delegators :@action_response, :text, :photo, :document, :parse_mode, :keyboard, :inline

    def send
      begin
        MyLogger.debug "sending '#{text}' to #{chat&.username || chat_id} (#{chat_id})"
        delete_previous_message if action_response.delete && message.present?

        send_with_params
      rescue StandardError => e
        MyLogger.error "Can't send #{text} to user. Error: #{e.message}"
        raise e if ENV['BOT_ENV'] != 'production'
        nil
      end
    end

    # only for callbacks
    def edit
      begin
        args = {
          chat_id:,
          message_id: message.message_id,
          parse_mode:,
          text:,
        }
        if action_response.inline
          args[:reply_markup] = action_response.reply_markup
        end

        args.merge!(action_response.opts) if action_response.opts.present?

        bot.api.edit_message_text(**args)
      rescue StandardError => e
        MyLogger.error "Can't send #{text} to user. Error: #{e.message}"
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
      photo_content = build_upload(final_photo, type: action_response.mime ||  'image/jpeg') 
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
        document: build_upload(document, type: action_response.mime ||  'image/jpeg'),
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
      if e.message.include?('can\'t parse entities')
        send_text(**args.merge(parse_mode: nil))
        MyLogger.warn "User received error in text: #{args[:text]}"
      end
    end

    def send_in_chunks(args, chunk_size = 4000)
      text.chars.each_slice(chunk_size) do |chunk|
        bot.api.send_message(**args.merge(text: chunk.join))
      end
    end

    def build_action_response(params)
      obj = params[:action_response]
      if obj.is_a?(Hash)
        ActionResponse.new(obj)
      elsif obj.respond_to?(:text)
        obj
      else
        raise ArgumentError
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
    rescue StandardError => e
      MyLogger.error "Cant delete #{message.message_id}, with new text: #{action_response.text}"
    end
  end
end
