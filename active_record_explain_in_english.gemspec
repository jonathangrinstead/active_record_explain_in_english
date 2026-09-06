
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "active_record_explain_in_english/version"

Gem::Specification.new do |spec|
  spec.name          = "active_record_explain_in_english"
  spec.version       = ActiveRecordExplainInEnglish::VERSION
  spec.authors       = ["Jonathan Grinstead"]
  spec.email         = ["jonathangrinstead@hey.com"]

  spec.summary       = "Translates ActiveRecord relations into plain English."
  spec.description   = "A gem that adds explain_in_english to ActiveRecord::Relation, translating common Arel query nodes into human-readable language."
  spec.homepage      = "https://github.com/jonathangrinstead/active_record_explain_in_english"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.1"

  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.org"
    spec.metadata["homepage_uri"] = "https://github.com/jonathangrinstead/active_record_explain_in_english#readme"
    spec.metadata["source_code_uri"] = "https://github.com/jonathangrinstead/active_record_explain_in_english"
    spec.metadata["changelog_uri"] = "https://github.com/jonathangrinstead/active_record_explain_in_english/blob/master/CHANGELOG.md"
    spec.metadata["rubygems_mfa_required"] = "true"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = Dir.chdir(File.expand_path("..", __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) || f.end_with?(".gem") }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 7.1", "< 8.2"

  spec.add_development_dependency "bundler", ">= 1.17", "< 5"
  spec.add_development_dependency "rake", ">= 10.0", "< 14"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "sqlite3", "~> 2.9"
  spec.add_development_dependency "database_cleaner-active_record", "~> 2.2"
end
