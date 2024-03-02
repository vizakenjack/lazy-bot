module LazyBot

  class InlineResponse < ActionResponse
    attr_accessor :text, :title, :inline, :results, :opts

    def initialize(params)
      @text = params[:text]
      @title = params[:title]
      @inline = params[:inline]
      @results = params[:results]
      @opts = params[:opts]
    end

    def present?
      results.present?
    end
  end
end