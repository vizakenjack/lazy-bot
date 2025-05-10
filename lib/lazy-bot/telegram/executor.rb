module LazyBot
  class Executor
    extend Forwardable

    attr_reader :chat_id, :context, :action_response

    def initialize(context, action_response)
      @context = context
      @action_response = action_response
    end

    def_delegators :@action_response, :text, :photo, :document, :parse_mode, :keyboard, :inline
    def_delegators :@context, :chat_id, :bot, :chat, :message
  end
end
