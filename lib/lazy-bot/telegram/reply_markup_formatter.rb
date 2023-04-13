# frozen_string_literal: true

module LazyBot
  class ReplyMarkupFormatter
    attr_reader :data

    def initialize(data)
      @data = data
    end

    def get_markup
      if data.blank?
        Telegram::Bot::Types::ReplyKeyboardRemove.new(remove_keyboard: true)
      else
        Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: data, one_time_keyboard: true, resize_keyboard: true)
      end
    end

    # {"bitcoin" => "/select_btc", "ethereum" => "/select_eth"}
    def get_inline_markup
      keyboard = entry_to_keyboard(data)
      keyboard = [keyboard] if data.is_a?(Hash)

      # keyboard = [
      #  [ Telegram::Bot::Types::InlineKeyboardButton.new(text: '1', callback_data: 'x')],
      #  [ Telegram::Bot::Types::InlineKeyboardButton.new(text: '2', callback_data: '3')],
      # ]

      Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: keyboard)
    end

    def entry_to_keyboard(entry)
      if entry.is_a?(Hash)
        entry.map { |k, v| Telegram::Bot::Types::InlineKeyboardButton.new(text: k.to_s, callback_data: v) }
      elsif entry.is_a?(Array)
        entry.map { |item| entry_to_keyboard(item).flatten }
      end
    end
  end
end
