# frozen_string_literal: true

module LazyBot
  class Config
    class << self
      # def redis
      #   @redis ||= RedisProxy.new
      # end

      # def last_update_id
      #   redis.get(UPDATE_ID_KEY).to_i
      # end

      # def last_update_id=(update_id)
      #   redis.set(UPDATE_ID_KEY, update_id)
      # end

      def debug_mode?
        false
        # redis.get('telegram_debug_mode').to_i > 0
      end

      def timeout
        120
      end

      def on_error(e)
      end

      def bot_names
        ['test']
      end

      def socket_path
        File.expand_path("../../shared/tmp/chatbot.sock")
      end

      def telegram_token
        raise StandardError, 'Token not set'
      end
    end
  end
end
