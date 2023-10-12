# frozen_string_literal: true

module LazyBot
  class CallbackAction < Action
    def match_message?
      false
    end

    def match_callback?
      true
    end
  end
end
