# frozen_string_literal: true

require_relative "lib/active_storage_client_side_encrypted/version"

Gem::Specification.new do |spec|
  spec.name = "active_storage_client_side_encrypted"
  spec.version = ActiveStorageClientSideEncrypted::VERSION
  spec.authors = ["Stefan Wienert"]
  spec.email = ["info@stefanwienert.de"]

  spec.summary = "ActiveStorage client side encrypted S3-Storage"
  spec.description = "ActiveStorage client side encrypted S3-Storage"
  spec.homepage = "https://github.com/pludoni/active_storage_client_side_encrypted"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  #spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "activestorage", ">= 7.0.0"
  spec.add_dependency "aws-sdk-s3", ">= 1.114.0"
end
