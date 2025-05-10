module LazyBot
  class StateAction < Action
    def match_message?
      true
    end

    def match_callback?
      true
    end
  end
end
