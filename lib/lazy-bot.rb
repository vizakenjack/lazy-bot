# frozen_string_literal: true

DEVELOPMENT = ENV["BOT_ENV"] != "production"

require "telegram/bot"
require "logger"
require 'forwardable'

require "lazy-bot/config"
require "lazy-bot/core/action"
# require "actions/state_action"
require "lazy-bot/core/callback_action"
require "lazy-bot/telegram/callback_responder"
require "lazy-bot/telegram/message_sender"
require "lazy-bot/telegram/reply_markup_formatter"
require "lazy-bot/engine"
