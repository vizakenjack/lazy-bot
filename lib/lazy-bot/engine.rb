# frozen_string_literal: true

require "find"

module LazyBot
  class Engine
    attr_reader :config

    def initialize(config)
      @actions = []
      @config = config

      opts = DEVELOPMENT ? { timeout: 1 } : { timeout: 360 }
      client = Telegram::Bot::Client.new(config.telegram_token, opts)
      @bot = DecoratedBotClient.new(client)
      @last_update_id = 0

      load_actions(config.actions_path)
    end

    delegate :telegram_username, to: :config

    def start!
      @bot.run do |bot|
        bot.listen do |message|
          respond_message(message)
        rescue Telegram::Bot::Exceptions::ResponseError => e
          raise e if DEVELOPMENT

          puts "Got telegram response error: #{e}"
        rescue StandardError => e
          MyLogger.error "message = #{e.message}"
          MyLogger.error "backtrace = #{e.backtrace.join('\n')}"
          raise if DEVELOPMENT
        end
      end
    end

    def process_webhook_request(params)
      update_id = params["update_id"]

      return unless new_request?(update_id)

      @last_update_id = update_id

      message = Telegram::Bot::Types::Update.new(params).current_message
      respond_message(message)
    end

    def new_request?(update_id)
      return true if update_id.nil? || update_id == 0

      update_id > @last_update_id
    end

    def respond_message(message)
      puts "message = #{message.to_h}" if DEVELOPMENT
      decorated_message = DecoratedMessage.new(message, config)

      return false if decorated_message.unsupported?

      repo = @config.repo_class.new(config:).tap { |r| r.find_or_create_user(decorated_message) }

      options = {
        bot: @bot,
        message: decorated_message,
        config:,
        repo:,
      }

      if decorated_message.document?
        MyLogger.important("Received document")
        handle_document(options, message)
      elsif decorated_message.photo?
        MyLogger.important("Received photo")
        handle_photos(options, message)
      elsif decorated_message.callback? || decorated_message.text_message?
        handle_text_message(options, decorated_message)
        # handle_callback(options, decorated_message)
        # elsif decorated_message.text_message?
        # handle_text_message(options, message)
      else
        handle_unknown_message(message)
      end
    end

    def handle_text_message(options, message)
      text = message.try(:text) || message.try(:data)
      MyLogger.warn("Received message: #{text}")

      # action_response = matched_action_response(options)
      matched_action = find_matched_action(options, message)
      return unless matched_action

      chat = message.callback? ? message.message.chat : message.chat
      responder = message.callback? ? CallbackResponder : MessageSender
      args = { bot: options[:bot], chat:, message: }

      if (before_finish_action = matched_action.before_finish)
        args.merge!(action_response: before_finish_action)
        responder.new(**args).send
      end

      action_response = matched_action.to_output

      # if action_response is ActionResponse.empty its being skipped
      if action_response.present?
        args.merge!(action_response:)
        responder.new(**args).send
      elsif action_response.nil?
        action_response = ActionResponse.text(I18n.t("errors.unknown_command"))
        args.merge!({ action_response: })
        responder.new(**args).send
      end

      if (after_finish_action = matched_action.after_finish)
        args.merge!(action_response: after_finish_action)
        responder.new(**args).send
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
      # if actions_path.is_a?(Array)
      #   return actions_path.each { |path| load_actions(path) }
      # end

      Find.find(actions_path) do |file|
        next if File.directory?(file)
        next if file == actions_path

        extname = File.extname(file)
        next if extname != ".rb"

        load(file)

        basename = File.basename(file, '.rb')
        module_name = file.split('/')[1].capitalize.classify
        class_name = basename.capitalize.classify
        class_object = "#{module_name}::#{class_name}".constantize

        puts "Added action #{class_object}"

        @actions << class_object

        # if class_object < CallbackAction
        #   @callbacks << class_object
        # else
        #   @actions << class_object
        # end
      end

      @actions.sort_by! { |e| -e::PRIORITY }
    end

    def find_matched_action(options, message)
      start_actions = []
      finish_actions = []

      @actions.each do |action_class|
        action = action_class.new(options)

        next if !action.match_message? && message.callback? == false
        next if !action.match_callback? && message.callback?

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

    # def find_matched_callback(options)
    #   @callbacks.each do |action_class|
    #     action = action_class.new(options)
    #     if action.start_condition || action.finish_condition
    #       return action
    #     end
    #   end

    #   MyLogger.error("Got no response for callback #{options}")

    #   nil
    # end
  end
end
