# frozen_string_literal: true

module LazyBot
  class ActionResponse
    attr_accessor :text, :notice, :keyboard, :inline, :photo, :parse_mode, :alert, :clear_inline, :edit_inline, :replace,
                  :opts

    def initialize(args)
      @text = args[:text]
      @notice = args[:notice]
      @keyboard = args[:keyboard] || []
      @inline = args[:inline]
      @photo = args[:photo]
      @parse_mode = args[:parse_mode]
      @alert = args[:alert]
      @clear_inline = args[:clear_inline]
      @edit_inline = args[:inline]
      @replace = args[:replace]
      @opts = args[:opts] || {}
    end

    # being skipped on handle_text_message
    def self.empty
      ActionResponse.new(text: '')
    end

    def self.text(text, args = {})
      ActionResponse.new(args.merge({ text: }))
    end

    def self.notice(notice, args = {})
      ActionResponse.new(args.merge({ notice: }))
    end

    def self.alert(notice, args = {})
      ActionResponse.new(args.merge({ notice:, alert: true }))
    end

    def present?
      text.present? || notice.present? || photo.present?
    end

    def reply_markup
      if inline
        ReplyMarkupFormatter.new(inline).get_inline_markup
      elsif keyboard
        ReplyMarkupFormatter.new(keyboard).get_markup
      end
    end
  end
end
