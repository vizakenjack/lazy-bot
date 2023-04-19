# frozen_string_literal: true

module LazyBot
  class CallbackAction < Action
    def initialize(options)
      super
      @callback = options[:message].data
    end

    def args
      @callback&.split
    end

    def start
    end

    def finish_condition
    end

    def before_finish
    end

    def finish
    end
  end
end
