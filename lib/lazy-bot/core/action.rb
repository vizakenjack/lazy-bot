# frozen_string_literal: true

module LazyBot
  class Action
    PRIORITY = 0

    attr_reader :options, :bot, :message, :text, :repo, :api, :user

    def initialize(options)
      @options = options
      @bot = options[:bot]
      @message = options[:message]
      @text = @message.try(:text) || @message.try(:data)
      @repo = options[:repo]
      @api = @repo&.api
      @user = options[:user]
    end

    def self.from_action(action, **opts)
      opts ||= {}
      new(action.options.merge(opts))
    end

    def self.from_callback(action, **opts)
      opts ||= {}
      opts.merge! message: action.message.message
      new(action.options.merge(opts))
    end

    def state_name
      ""
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
      # @user.reset_state
    end

    def ask
      { text: I18n.t(state_name) }
    end

    def redraw_inline
    end

    def to_output
      if start_condition
        start
      elsif finish_condition
        finish
      end
    rescue Exception => e
      Engine.сonfig.on_error(e)
      MyLogger.error "message = #{e.message}"
      MyLogger.error "backtrace = #{e.backtrace.join('\n')}"
      raise e if DEVELOPMENT

      { text: I18n.t("errors.default_error") }
    end

    def reset_user!
      # USERS.delete(message.from.id)
      # @user = find_or_create_user!(message)
      # @user.reset_state
    end
  end
end
