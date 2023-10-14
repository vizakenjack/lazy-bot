# frozen_string_literal: true

module LazyBot
  class MessageSender
    extend Forwardable

    attr_reader :bot, :text, :chat, :chat_id, :action_response, :message

    def initialize(params)
      @bot = params[:bot]
      @chat = params[:chat]
      @chat_id = params[:chat]&.id || params[:id] || params[:message]&.chat&.id
      @action_response = build_action_response(params)
      @message = params[:message]
    end

    def_delegators :@action_response, :text, :photo, :parse_mode, :keyboard, :inline

    def send
      begin
        send_with_params
      rescue StandardError => e
        MyLogger.error "Can't send #{text} to user. Error: #{e.message}"
      end

      MyLogger.debug "sending '#{text}' to #{chat&.username || chat_id} (#{chat_id})"
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

      args.merge!(action_response.opts) if action_response.opts.present?

      if photo
        args[:caption] = text
        send_photo_with_caption(args)
      else
        args[:text] = text
        send_text(args)
      end
    end

    def send_photo_with_caption(args)
      photo_data = {
        photo: Faraday::UploadIO.new(photo, "image/jpeg"),
      }
      args.merge!(photo_data)

      bot.api.send_photo(**args)
    end

    def send_text(args)
      if text.length >= 4000
        send_in_chunks(args)
      else
        bot.api.send_message(**args)
      end
    rescue StandardError => e
      MyLogger.error "send_text error, length is #{text.length}. Error: #{e.message}"

      raise e if DEVELOPMENT

      if e.message.include?('can\'t parse entities')
        send_text(**args.merge(parse_mode: nil))
        MyLogger.warn "User received error in text: #{args[:text]}"
        MyLogger.important "User received error in text: #{args[:text]}"
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
  end
end
