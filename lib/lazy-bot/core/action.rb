# frozen_string_literal: true

module LazyBot
  class Action
    extend Forwardable
    PRIORITY = 0

    attr_reader :repo, :text

    def initialize(repo)
      @repo = repo
      @text = @repo.message.content
    end

    def_delegators :@repo, :api, :user, :bot, :message, :config

    alias callback text

    def self.from_action(action)
      new(action.repo)
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

    def match_photo?
      false
    end

    def match_callback?
      false
    end

    def match_inline?
      false
    end

    def match_document?
      false
    end

    def match_voice?
      false
    end

    def match_video?
      false
    end

    def match_group?
      message.respond_to?(:mention?) && message.mention?
    end

    def match_private?
      true
    end

    def match_new_chat_members?
      false
    end

    def match_left_chat_member?
      false
    end

    def user_state
      user.opts.dig('state', config.bot_id.to_s) || ''
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
