# frozen_string_literal: true

require "telegram/bot"
require "logger"
require 'forwardable'
require 'delegate'

require "lazy-bot/my_logger"
require "lazy-bot/decorators/decorated_bot_client"
require "lazy-bot/decorators/decorated_message"
require "lazy-bot/telegram/reply_markup_formatter"
require "lazy-bot/telegram/callback_responder"
require "lazy-bot/telegram/inline_responder"
require "lazy-bot/telegram/message_sender"
require "lazy-bot/core/action_response"
require "lazy-bot/core/inline_response"
require "lazy-bot/config"
require "lazy-bot/core/action"
require "lazy-bot/core/callback_action"
require "lazy-bot/core/state_action"
require "lazy-bot/core/inline_action"
require "lazy-bot/engine"
require "lazy-bot/context"
