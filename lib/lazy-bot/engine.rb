# rubocop:disable Style/ClassVars
# frozen_string_literal: true

module LazyBot
  class Engine
    extend Forwardable

    attr_reader :config

    def initialize(config)
      @@loaded_actions = []

      @actions = []
      @config = config

      opts = ENV['BOT_ENV'] == 'development' ? { timeout: 1 } : { timeout: 360 }
      client = Telegram::Bot::Client.new(config.telegram_token, opts)
      @bot = DecoratedBotClient.new(client)
      @last_update_id = 0

      load_actions(config.actions_path)
    end

    def_delegators :@config, :bot_username

    def start!
      @bot.run do |bot|
        bot.listen do |message|
          respond_message(message)
        rescue Telegram::Bot::Exceptions::ResponseError => e
          raise e if ENV['BOT_ENV'] == 'development'

          puts "Got telegram response error: #{e}"
        rescue StandardError => e
          MyLogger.error "message = #{e.message}"
          MyLogger.error "backtrace = #{e.backtrace.join('\n')}"
          raise if ENV['BOT_ENV'] == 'development'
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
      puts "message = #{message.to_h}" if ENV['BOT_ENV'] == 'development' || ENV['BOT_ENV'] == 'staging'
      decorated_message = DecoratedMessage.new(message, config)

      return false if decorated_message.unsupported?

      repo = @config.repo_class.new(config:).tap { |r| r.find_or_create_user(decorated_message) }

      options = {
        bot: @bot,
        message: decorated_message,
        config:,
        repo:,
      }

      if decorated_message.photo?
        handle_photos(options, message)
      elsif decorated_message.callback? || decorated_message.text_message? || decorated_message.document? || decorated_message.voice?
        handle_message(options, decorated_message)
      else
        handle_unknown_message(message)
      end
    end

    def handle_message(options, message)
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

    def handle_photos(options, message)
      args = { bot: options[:bot], chat: message.chat }

      action_response = ActionResponse.text("Бот пока не умеет распознавать фото — эта возможность появится, когда откроют доступ для разработчиков")
      args.merge!({ action_response: })

      MessageSender.new(**args).send
    end

    def handle_unknown_message(message)
      text = message.try(:text) || message.try(:data)
      MyLogger.warn("Unknown message: #{text}")
    end

    def load_actions(actions_path)
      return if @@loaded_actions.include?(actions_path)

      find_files(actions_path) do |file|
        next if File.directory?(file)
        next if file == actions_path

        extname = File.extname(file)
        next if extname != ".rb"

        basename = File.basename(file, '.rb')
        module_name = file.split('/')[1].capitalize.classify
        class_name = basename.capitalize.classify

        file_path = "#{Dir.pwd}/#{file}"
        require(file_path)
        class_object = "#{module_name}::#{class_name}".constantize

        puts "Added action #{class_object}"

        @actions << class_object
      end

      @@loaded_actions << actions_path

      @actions.sort_by! { |e| -e::PRIORITY }
    end

    private

    def find_matched_action(options, message)
      start_actions = []
      finish_actions = []

      @actions.each do |action_class|
        action = action_class.new(options)

        result = false
        result ||= action.match_message? && message.text_message?
        result ||= action.match_document? && message.document?
        result ||= action.match_callback? && message.callback?
        result ||= action.match_voice? && message.voice?

        next unless result

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

    def find_files(*paths, ignore_error: true) # :yield: path
      block_given? or return enum_for(__method__, *paths, ignore_error:)

      fs_encoding = Encoding.find("filesystem")

      paths.collect! do |d|
        raise Errno::ENOENT, d unless File.exist?(d)

        d.dup
      end.each do |path|
        path = path.to_path if path.respond_to? :to_path
        enc = path.encoding == Encoding::US_ASCII ? fs_encoding : path.encoding
        ps = [path]
        while file = ps.shift
          yield file.dup
          begin
            s = File.lstat(file)
          rescue Errno::ENOENT, Errno::EACCES, Errno::ENOTDIR, Errno::ELOOP, Errno::ENAMETOOLONG, Errno::EINVAL
            raise unless ignore_error

            next
          end
          next unless s.directory?

          begin
            fs = Dir.children(file, encoding: enc)
          rescue Errno::ENOENT, Errno::EACCES, Errno::ENOTDIR, Errno::ELOOP, Errno::ENAMETOOLONG, Errno::EINVAL
            raise unless ignore_error

            next
          end
          fs.sort!
          fs.reverse_each do |f|
            f = File.join(file, f)
            ps.unshift f
          end
        end
      end
      nil
    end
  end
end

# rubocop:enable Style/ClassVars
