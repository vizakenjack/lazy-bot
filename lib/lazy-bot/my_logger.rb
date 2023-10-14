# frozen_string_literal: true

module LazyBot
  class MyLogger
    attr_accessor :logger

    DEFAULT_LOGGER_LEVEL = Logger::INFO

    def initialize(logger_name = 'bot.log')
      @logger = Logger.new("./log/#{logger_name}").tap do |obj|
        obj.level = DEFAULT_LOGGER_LEVEL
      end
    end

    def self.debug(text = nil)
      new('bot.log').tap do |log|
        log.level = Logger::DEBUG
        log.debug(text) if text
      end
    end

    def self.info(text = nil)
      new('bot.log').tap { |log| log.info(text) if text }
    end

    def self.warn(text = nil)
      new('bot.log').tap { |log| log.warn(text) if text }
    end

    def self.error(text = nil)
      puts text if DEVELOPMENT
      new('error.log').tap { |log| log.error(text) if text }
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
