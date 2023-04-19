# frozen_string_literal: true

module LazyBot
  class Action
    PRIORITY = 0

    attr_reader :options, :bot, :user_states, :message, :text, :repo, :api, :user

    def initialize(options)
      @options = options
      @bot = options[:bot]
      @message = options[:message]
      @text = @message.try(:text) || @message.try(:data)
      @repo = options[:repo]
      @api = @repo&.api
      @user = options[:user]
      @user_states = options[:user_states]
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

    def state
      user_states[user.id] || {}
    end

    def update_state(new_state_name, new_state_value)
      user_states[user.id] ||= {}
      user_states[user.id][new_state_name] = new_state_value
    end

    def reset_state
      user_states[user.id] = {}
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
      LazyBot.config.on_error(e)
      MyLogger.error "message = #{e.message}"
      MyLogger.error "backtrace = #{e.backtrace.join('\n')}"
      raise e if DEVELOPMENT

      { text: I18n.t("errors.default_error") }
    end
  end
end
