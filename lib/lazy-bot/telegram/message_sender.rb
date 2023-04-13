# frozen_string_literal: true

module LazyBot
  class MessageSender
    extend Forwardable

    attr_reader :bot, :text, :chat, :chat_id, :action_response

    def initialize(options)
      @bot = options[:bot]
      @chat = options[:chat]
      @chat_id = options[:chat]&.id || options[:id] || options[:message]&.chat&.id
      @action_response = build_action_response(options)
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

    private

    def send_with_params
      args = {
        chat_id:,
        reply_markup: action_response.reply_markup,
        parse_mode:,
      }

      args.merge!(action_response.opts) if action_response.opts.present?

      if photo
        send_photo_with_caption(args)
      else
        send_text(args)
      end
    end

    def send_photo_with_caption(args)
      photo_data = {
        caption: text,
        photo: Faraday::UploadIO.new(photo, "image/jpeg"),
      }
      args.merge!(photo_data)

      bot.api.send_photo(**args)
    end

    def send_text(args)
      args[:text] = text

      if text.length >= 8000
        bot.api.send_message(**args.merge(text: text[0...4000]))
        bot.api.send_message(**args.merge(text: text[4000..8000]))
        bot.api.send_message(**args.merge(text: text[8000..]))
      elsif text.length >= 4000
        bot.api.send_message(**args.merge(text: text[0...4000]))
        bot.api.send_message(**args.merge(text: text[4000..]))
      else
        bot.api.send_message(**args)
      end
    rescue StandardError => e
      if e.message.include?('can\'t parse entities')
        bot.api.send_message(**args.merge(parse_mode: nil))
      end
    end

    def build_action_response(options)
      obj = options[:action_response]
      if obj.is_a?(Hash)
        ActionResponse.new(obj)
      else
        obj
      end
    end
  end
end
