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

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  # spec.files = Dir.chdir(File.expand_path(__dir__)) do
  #   `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  # end
  spec.files = Dir['lib/**/*.rb']
  # spec.bindir = "exe"
  # spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "telegram-bot-ruby", "~> 1.0"
  spec.add_development_dependency "bundler", "~> 2.3"
  spec.add_development_dependency "rake", "~> 13.0.1"
  # spec.add_development_dependency "rspec", "~> 3.0"
end
