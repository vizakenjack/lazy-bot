# frozen_string_literal: true

module LazyBot
  class InlineResponder
    extend Forwardable

    attr_reader :message, :bot, :action_response

    def initialize(params)
      @bot = params[:bot]
      @message = params[:message]
      @action_response = params[:action_response]
    end

    def_delegators :@action_response, :text, :notice, :photo

    def send
      return false if action_response.is_a?(InlineResponse) == false
      
      @bot.api.answer_inline_query(inline_query_id: message.id, results: action_response.results, is_personal: true, cache_time: 0)
    rescue Telegram::Bot::Exceptions::ResponseError
      "ok"
    end

  end
end
