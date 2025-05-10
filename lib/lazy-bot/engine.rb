# rubocop:disable Style/ClassVars
# frozen_string_literal: true

module LazyBot
  class Engine
    extend Forwardable

    attr_reader :config, :bot

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
      puts "respond_message: #{message.to_h}" if ['development', 'staging'].include?(ENV['BOT_ENV'])
      decorated_message = DecoratedMessage.new(message, config)

      return false if decorated_message.unsupported?

      context = Context.new(bot:, config:, message:)

      if decorated_message.supported?
        handle_message(context)
      else
        handle_unknown_message(message)
      end
    end

    def handle_message(context)
      message = context.message
      text = message.try(:text) || message.try(:data)
      MyLogger.warn("Received message: #{text}")

      matched_action = find_matched_action(context)
      if matched_action.nil?
        puts "Cant find matched action for #{text}" if DEVELOPMENT
        return
      end

      responder = find_responder(message)

      if (before_finish_action = matched_action.before_finish)
        responder.new(context, action_response: before_finish_action).send
      end

      if matched_action.webhook_response?
        puts "Handle sync"
        handle_sync(responder, matched_action)
      else
        puts "Handle async"
        handle_async(responder, matched_action)

        ActionResponse.empty
      end
    end

    def handle_sync(responder, matched_action)
      action_response = matched_action.to_output

      puts "action_response2 = #{action_response}"
      puts "message = #{matched_action.message.inspect}"
      puts "message.chat_id = #{matched_action.message.chat_id.inspect}"
      # return {
      #   method: 'sendMessage',
      #   chat_id: message.chat_id,
      #   text: 'Success new!!!',
      # }
      # Async do
      #   if (after_finish_action = matched_action.after_finish)
      #     sleep 10
      #     args.merge!(action_response: after_finish_action)
      #     responder.new(**args).send
      #   end
      # end

      x =  action_response.as_json(chat_id: matched_action.message.chat_id)
      puts "x =#{x}"
      x
    end

    def handle_async(responder, matched_action)
      Async do
        action_response = matched_action.to_output

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

    def find_matched_action(context)
      message = context.message
      start_actions = []
      finish_actions = []

      @actions.each do |action_class|
        action = action_class.new(context)

        result = false
        if message.in_group?
          next if action.match_group? == false
        elsif action.match_private? == false
          next
        end

        result ||= message.text_message? && action.match_message?
        result ||= message.document? && action.match_document?
        result ||= message.callback? && action.match_callback?
        result ||= message.inline_query? && action.match_inline?
        result ||= message.voice? && action.match_voice?
        result ||= message.video? && action.match_video?
        result ||= message.photo? && action.match_photo?
        result ||= message.audio? && action.match_audio?
        result ||= message.left_chat_member? && action.match_left_chat_member?
        result ||= message.new_chat_members? && action.match_new_chat_members?

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

    private

    def find_responder(message)
      if message.callback?
        CallbackResponder
      elsif message.inline_query?
        InlineResponder
      else
        MessageSender
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
