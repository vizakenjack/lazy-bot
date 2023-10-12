# frozen_string_literal: true

module LazyBot
  class Config
    attr_reader :bot_username, :bot_env, :bot_role, :bot_url, :timeout, :telegram_token, :debug_mode,
                :actions_path, :repo_class

    def initialize(file, repo_class:)
      full_conf = YAML.load_file(file).deep_symbolize_keys
      env = ENV['BOT_ENV'] || 'development'
      conf = full_conf[env.to_sym]

      @bot_username = conf[:bot_username] || raise('Username is not set')
      @bot_env = conf[:bot_env] || 'development'
      @bot_role = conf[:bot_role] || 'default'
      @timeout = conf[:timeout] || 120
      @debug_mode = conf[:debug_mode] || false
      @telegram_token = conf[:telegram_token] || raise('Token is not set')
      @actions_path = conf[:actions_path] || raise('Actions path is not set')
      @repo_class = repo_class
    end

    def on_error(error)
      nil
    end
  end
end
