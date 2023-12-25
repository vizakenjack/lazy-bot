# frozen_string_literal: true

module LazyBot
  class ActionResponse
    attr_accessor :text, :notice, :keyboard, :inline, :photo, :document, :parse_mode, :alert, :clear_inline, :edit_inline, :edit, :replace,
                  :opts

    def initialize(params)
      @text = params[:text]
      @notice = params[:notice]
      @keyboard = params[:keyboard] || []
      @inline = params[:inline]
      @photo = params[:photo]
      @document = params[:document]
      @parse_mode = params[:parse_mode]
      @alert = params[:alert]
      @clear_inline = params[:clear_inline]
      @edit_inline = params[:edit_inline]
      @replace = params[:replace]
      @edit = params[:edit]
      @opts = params[:opts]
    end

    # being skipped on handle_text_message
    def self.empty
      ActionResponse.new(text: '')
    end

    def self.text(text, params = {})
      params[:opts] ||= {}
      params[:opts][:disable_web_page_preview] = true
      ActionResponse.new(params.merge({ text: }))
    end

    def self.notice(notice, params = {})
      ActionResponse.new(params.merge({ notice: }))
    end

    def self.alert(notice, params = {})
      ActionResponse.new(params.merge({ notice:, alert: true }))
    end

    def self.markdown(text, params = {})
      params[:text] = text
      params[:opts] ||= {}
      params[:opts][:parse_mode] = 'Markdown'
      params[:opts][:disable_web_page_preview] = true
      ActionResponse.new(params)
    end

    def self.html(text, params = {})
      params[:text] = text
      params[:opts] ||= {}
      params[:opts][:parse_mode] = 'html'
      params[:opts][:disable_web_page_preview] = true
      ActionResponse.new(params)
    end

    def present?
      text.present? || notice.present? || photo.present? || inline.present?
    end

    def reply_markup
      if inline
        ReplyMarkupFormatter.new(inline).build_inline_markup
      elsif keyboard
        ReplyMarkupFormatter.new(keyboard).build_markup
      end
    end
  end
end
