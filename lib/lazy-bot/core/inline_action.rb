# frozen_string_literal: true

module LazyBot
  class InlineAction < Action
    def match_message?
      false
    end

    def match_callback?
      false
    end

    def match_inline?
      true
    end
  end
end
