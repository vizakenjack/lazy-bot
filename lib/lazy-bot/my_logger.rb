# frozen_string_literal: true

class MyLogger
  attr_accessor :logger

  DEFAULT_LOGGER_LEVEL = Logger::INFO

  def initialize(logger_name = 'info.log')
    @logger = Logger.new("./log/#{logger_name}.log")
    @logger.level = DEFAULT_LOGGER_LEVEL
  end

  def self.debug(text = nil)
    if text
      new('debug.log').debug(text)
    else
      new('debug.log')
    end
  end

  def self.info(text = nil)
    if text
      new('info.log').info(text)
    else
      new('info.log')
    end
  end

  def self.error(text = nil)
    if text
      new('error.log').error(text)
    else
      new('error.log')
    end
  end

  def self.important
    new('important.log')
  end

  def self.sinatra
    new('sinatra.log')
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
