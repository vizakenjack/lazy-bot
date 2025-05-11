module LazyBot
  class InlineResponder
    extend Forwardable

    attr_reader :context, :action_response

    def initialize(context, action_response, **opts)
      @context = context
      @action_response = action_response
    end

    def_delegators :@context, :message, :bot
    def_delegators :@action_response, :text, :notice, :photo

    def build_actions
      return [] unless action_response.is_a?(InlineResponse)

      [
        {
          method: 'answerInlineQuery',
          inline_query_id: message.id,
          results: action_response.results,
          is_personal: true,
          cache_time: 0,
        }
      ]
    end

    def execute(actions = nil)
      return false if action_response.is_a?(InlineResponse) == false

      bot.api.answer_inline_query(inline_query_id: message.id, results: action_response.results, is_personal: true,
                                  cache_time: 0)
    rescue Telegram::Bot::Exceptions::ResponseError
      'ok'
    end
  end
end
