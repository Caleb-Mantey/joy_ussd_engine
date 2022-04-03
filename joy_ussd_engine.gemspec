# frozen_string_literal: true

require_relative "lib/joy_ussd_engine/version"

Gem::Specification.new do |spec|
  spec.name          = "joy_ussd_engine"
  spec.version       = JoyUssdEngine::VERSION
  spec.authors       = ["Caleb Mantey"]
  spec.email         = ["manteycaleb@gmail.com"]

  spec.summary       = "A gem for building ussd and text based applications rapidly."
  spec.description   = "A ruby library for building text based applications rapidly. It supports building whatsapp, ussd, telegram and various text or chat applications that communicate with your rails backend. With this library you can target multiple platforms(whatsapp, ussd, telegram, etc.) at once with just one codebase."
  spec.homepage      = "https://github.com/Caleb-Mantey/joy_ussd_engine"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.4.0"

  # spec.metadata["allowed_push_host"] = "'https://rubygems.org'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/Caleb-Mantey/joy_ussd_engine"
  spec.metadata["changelog_uri"] = "https://github.com/Caleb-Mantey/joy_ussd_engine/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir['**/*'] do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features|images)/}) }
  end

  # spec.files = `git ls-files -z`.split("\x0").reject do |f|
  #   f.match(%r{^(test|spec|features)/})
  # end

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"
  spec.add_dependency "will_paginate", "~> 3.3.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "redis"

  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html
end
