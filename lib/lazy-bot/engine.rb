# frozen_string_literal: true

require "find"

module LazyBot
  class << self
    def configure(**args)
      @config = Config.new(**args)
    end

    attr_reader :config
  end

  class Engine
    def initialize(**args)
      @actions = []
      @callbacks = []

      LazyBot.configure(**args)

      opts = DEVELOPMENT ? { timeout: 1 } : { timeout: LazyBot.config.timeout + 60 }
      client = Telegram::Bot::Client.new(LazyBot.config.telegram_token, opts)
      @bot = DecoratedBotClient.new(client)

      raise StandardError, 'Bot ENV is not set' unless ENV['BOT_ENV']
      raise StandardError, 'Bot role is not set' unless ENV['BOT_ROLE']
    end

    def start!
      @bot.run do |bot|
        bot.listen do |message|
          respond_message(message)
        rescue Telegram::Bot::Exceptions::ResponseError => e
          puts "Got telegram response error: #{e}"
        rescue Exception => e
          if e.message != "SIGTERM" && e.message != "exit"
            MyLogger.error "message = #{e.message}"
            MyLogger.error "backtrace = #{e.backtrace.join('\n')}"
          end
          raise if DEVELOPMENT
        end
      end
    end

    def respond_message(message)
      puts "message = #{message.to_h}" if DEVELOPMENT
      decorated_message = DecoratedMessage.new(message)

      return false if decorated_message.unsupported?

      repo = Repo.new.tap { |r| r.find_or_create_user(decorated_message) }

      options = {
        bot: @bot,
        message: decorated_message,
        repo:,
        user: repo.user,
      }

      if decorated_message.document?
        MyLogger.important("Received document")
        handle_document(options, message)
      elsif decorated_message.photo?
        MyLogger.important("Received photo")
        handle_photos(options, message)
      elsif decorated_message.callback?
        handle_callback(options, decorated_message)
      elsif decorated_message.text_message?
        handle_text_message(options, message)
      else
        handle_unknown_message(message)
      end
    end

    def handle_callback(options, decorated_message)
      matched_callback = find_matched_callback(options)
      return unless matched_callback

      args = { bot: options[:bot], callback: decorated_message }

      action_response = matched_callback.to_output

      if (before_finish_action = matched_callback.before_finish)
        args.merge!(action_response: before_finish_action)
        CallbackResponder.new(**args).respond
      end

      if action_response
        args.merge!({ action_response: })
        CallbackResponder.new(**args).respond
      end

      if (after_finish_action = matched_callback.after_finish)
        args.merge!(action_response: after_finish_action)
        CallbackResponder.new(**args).respond
      end
    end

    def handle_text_message(options, message)
      text = message.try(:text) || message.try(:data)
      MyLogger.warn("Received message: #{text}")

      # action_response = matched_action_response(options)
      matched_action = find_matched_action(options)
      return unless matched_action

      args = { bot: options[:bot],  chat: message.chat }

      if (before_finish_action = matched_action.before_finish)
        args.merge!(action_response: before_finish_action)
        MessageSender.new(**args).send
      end

      action_response = matched_action.to_output

      # if action_response is ActionResponse.empty its being skipped
      if action_response.present?
        args.merge!(action_response:)
        MessageSender.new(**args).send
      elsif action_response.nil?
        action_response = ActionResponse.text(I18n.t("errors.unknown_command"))
        args.merge!({ action_response: })
        MessageSender.new(**args).send
      end

      if (after_finish_action = matched_action.after_finish)
        args.merge!(action_response: after_finish_action)
        MessageSender.new(**args).send
      end
    end

    def handle_document(options, message)
      args = { bot: options[:bot], chat: message.chat }

      action_response = ActionResponse.text("К сожалению, бот пока не умеет открывать документы")
      args.merge!({ action_response: })

      MessageSender.new(**args).send
    end

    def handle_photos(options, message)
      args = { bot: options[:bot], chat: message.chat }

      action_response = ActionResponse.text("К сожалению, бот пока не умеет распознавать фото")
      args.merge!({ action_response: })

      MessageSender.new(**args).send
    end

    def handle_unknown_message(message)
      text = message.try(:text) || message.try(:data)
      MyLogger.warn("Unknown message: #{text}")
    end

    def load_actions(actions_path)
      if actions_path.is_a?(Array)
        return actions_path.each { |path| load_actions(path) }
      end

      Find.find(actions_path) do |file|
        next if File.extname(file) != ".rb"

        load(file)

        basename = File.basename(file, '.rb')
        class_name = basename.capitalize.classify.constantize

        puts "Added action #{class_name}"

        if class_name < CallbackAction
          @callbacks << class_name
        else
          @actions << class_name
        end
      end

      @actions.sort_by! { |e| -e::PRIORITY }
    end

    def find_matched_action(options)
      start_actions = []
      finish_actions = []

      @actions.each do |action_class|
        action = action_class.new(options)

        if action.start_condition
          start_actions << action
          break
        elsif action.finish_condition
          finish_actions << action
        end
      end

      if start_actions.any?
        start_actions.first
      elsif finish_actions.any?
        finish_actions.first
      end
    end

    def find_matched_callback(options)
      @callbacks.each do |action_class|
        action = action_class.new(options)
        if action.start_condition || action.finish_condition
          return action
        end
      end

      MyLogger.error("Got no response for callback #{options}")

      nil
    end
  end
end
