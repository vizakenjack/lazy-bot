# frozen_string_literal: true

module LazyBot
  LOGGERS = {} # rubocop:disable Style/MutableConstant

  class MyLogger
    attr_accessor :logger

    DEFAULT_LOGGER_LEVEL = Logger::INFO

    def initialize(logger_name = 'bot.log')
      @logger = Logger.new("./log/#{logger_name}").tap do |obj|
        obj.level = DEFAULT_LOGGER_LEVEL
        LOGGERS[logger_name] = obj
      end
    end

    def self.find_or_init(logger_name)
      LOGGERS[logger_name] ||= new(logger_name)
      LOGGERS[logger_name].logger
    end

    def self.debug(text = nil)
      find_or_init('bot.log').tap do |log|
        log.level = Logger::DEBUG
        log.debug(text) if text
      end
    end

    def self.info(text = nil)
      find_or_init('bot.log').tap { |log| log.info(text) if text }
    end

    def self.warn(text = nil)
      find_or_init('bot.log').tap { |log| log.warn(text) if text }
    end

    def self.error(text = nil)
      puts text if ENV['BOT_ENV'] == 'development' || ENV['BOT_ENV'] == 'staging'
      find_or_init('error.log').tap { |log| log.error(text) if text }
    end

    def level=(level)
      @logger.level = level
    end

    def debug(message, user: nil)
      message = "User id=#{user.id} name=#{user.name}: #{message}" if user
      @logger.debug(message)
    end

    def info(message, user: nil)
      message = "User id=#{user.id} name=#{user.name}: #{message}" if user
      @logger.info(message)
    end

    def error(message, user: nil)
      message = "User id=#{user.id} name=#{user.name}: #{message}" if user
      @logger.error(message)
    end

    def warn(message, user: nil)
      message = "User id=#{user.id} name=#{user.name}: #{message}" if user
      @logger.warn(message)
    end
  end
end
