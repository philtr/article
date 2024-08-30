# frozen_string_literal: true

require_relative "article/version"

module Article
  class Error < StandardError; end

  autoload :Client, "article/client"
end
