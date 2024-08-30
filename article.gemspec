# frozen_string_literal: true

require_relative "lib/article/version"

Gem::Specification.new do |spec|
  spec.name = "article"
  spec.version = Article::VERSION
  spec.authors = ["Phillip Ridlen"]
  spec.email = ["p@rdln.net"]

  spec.summary = "NNTP client"
  spec.description = "Article is an NNTP client that can be used to fetch articles from a Usenet server."
  spec.homepage = "https://github.com/philtr/article"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rspec", "~> 3.0"
end
