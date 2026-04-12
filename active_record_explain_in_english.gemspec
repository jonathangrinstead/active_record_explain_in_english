
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "active_record_explain_in_english/version"

Gem::Specification.new do |spec|
  spec.name          = "active_record_explain_in_english"
  spec.version       = ActiveRecordExplainInEnglish::VERSION
  spec.authors       = ["Jonny Grinstead"]
  spec.email         = ["jonathangrinstead.design@gmail.com"]

  spec.summary       = "Translates ActiveRecord query plans into plain English."
  spec.description   = "A gem that adds explain_in_english to ActiveRecord::Relation, translating SQL EXPLAIN output into human-readable language."
  spec.homepage      = "https://github.com/jonnygrinstead/active_record_explain_in_english"

  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.org"
    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = "https://github.com/jonnygrinstead/active_record_explain_in_english"
    spec.metadata["changelog_uri"] = "https://github.com/jonnygrinstead/active_record_explain_in_english/blob/master/CHANGELOG.md"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord"

  spec.add_development_dependency "bundler", ">= 1.17"
  spec.add_development_dependency "rake", ">= 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "database_cleaner-active_record"
end
