# frozen_string_literal: true

module LazyBot
  class Config
    attr_reader :conf, :bot_username, :bot_env, :telegram_token, :actions_path, :repo_class

    def initialize(file, repo_class:)
      full_conf = YAML.load_file(file).deep_symbolize_keys
      env = ENV['BOT_ENV'] || 'development'
      @conf = full_conf[env.to_sym]

      @bot_username = conf[:bot_username] || raise('Username is not set')
      @bot_env = conf[:bot_env] || 'development'
      @telegram_token = conf[:telegram_token] || raise('Token is not set')
      @actions_path = conf[:actions_path] || raise('Actions path is not set')
      @repo_class = repo_class
    end

    def on_error(error)
      nil
    end
  end
end
