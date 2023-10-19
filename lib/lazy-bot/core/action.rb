# frozen_string_literal: true

module LazyBot
  class Action
    extend Forwardable
    PRIORITY = 0

    attr_reader :bot, :text, :message, :repo, :config, :params

    def initialize(params)
      raise ArgumentError, 'Bot is not set' unless params[:bot]
      raise ArgumentError, 'Message is not set' unless params[:message]
      raise ArgumentError, 'Config is not set' unless params[:config]
      raise ArgumentError, 'Repo is not set' unless params[:repo]

      @bot = params[:bot]
      @message = params[:message]
      @repo = params[:repo]
      @config = params[:config]
      @text = @message.content
      # params to be used in from_action
      @params = params
    end

    def_delegators :@repo, :api, :user

    alias callback text

    def self.from_action(action, **opts)
      opts ||= {}
      new(action.params.merge(opts))
    end

    def start_condition
      nil
    end

    def finish_condition
      nil
    end

    def before_finish
    end

    def after_finish
    end

    def finish
      nil
    end

    def start
      nil
    end

    def ask
      nil
    end

    def redraw_inline
    end

    def match_message?
      true
    end

    def match_callback?
      false
    end

    def match_document?
      false
    end

    def to_output
      if start_condition
        start
      elsif finish_condition
        finish
      end
    rescue StandardError => e
      config.on_error(e)
      MyLogger.error "message = #{e.message}"
      MyLogger.error "backtrace = #{e.backtrace.join('\n')}"

      ActionResponse.text(config.error_message)
    end
  end
end
