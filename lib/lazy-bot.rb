# frozen_string_literal: true

DEVELOPMENT = ENV["BOT_ENV"] != "production"

require "telegram/bot"
require "logger"

require "lazy-bot/config"
require "lazy-bot/ccore/action"
# require "actions/state_action"
require "lazy-bot/ccore/callback_action"
require "lazy-bot/ctelegram/callback_responder"
require "lazy-bot/ctelegram/message_sender"
require "lazy-bot/ctelegram/reply_markup_formatter"
require "lazy-bot/cengine"
