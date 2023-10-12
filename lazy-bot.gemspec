# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "lazy-bot/version"

Gem::Specification.new do |spec|
  spec.name = "lazy-bot"
  spec.version = LazyBot::VERSION
  spec.authors = ["Ivan Tumanov"]
  spec.email = ["vizakenjack@gmail.com"]
  spec.licenses = ["MIT"]
  spec.summary = 'Telegram bot'
  spec.description = 'Telegram bot'
  spec.homepage = "https://github.com/vizakenjack/lazy-bot"

  spec.files = Dir['lib/**/*.rb']
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "telegram-bot-ruby", "~> 1.0"
  spec.add_development_dependency "bundler", "~> 2.3"
  spec.add_development_dependency "rake", "~> 13.0.1"
end
