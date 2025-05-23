module LazyBot
  class ActionResponse
    attr_accessor :text, :notice, :keyboard, :inline, :photo, :document, :audio, :mime, :alert, :clear_inline,
                  :edit_inline, :edit, :delete, :opts

    def initialize(params)
      # @temp
      @params = params

      @text = params[:text]
      raise TypeError, 'text must be a string' if @text.present? && !text.is_a?(String)

      @notice = params[:notice]
      @keyboard = params[:keyboard] || []
      @inline = params[:inline]
      @photo = params[:photo]
      @document = params[:document]
      @audio = params[:audio]
      @mime = params[:mime]
      @alert = params[:alert]
      @clear_inline = params[:clear_inline]
      @edit_inline = params[:edit_inline]
      @delete = params[:delete]
      @edit = params[:edit]
      @opts = params[:opts] || {}

      if params[:parse_mode]
        @opts[:parse_mode] = params[:parse_mode]
      end
    end

    def self.from_json(json)
      if json.is_a?(String)
        text(json)
      else
        new(**json['action'].symbolize_keys, opts: { disable_web_page_preview: true })
      end
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
      text.present? || notice.present? || photo.present? || inline.present? || document.present? || audio.present? || delete
    end

    def to_s
      "#{@params}"
    end

    def parse_mode
      opts[:parse_mode]
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
