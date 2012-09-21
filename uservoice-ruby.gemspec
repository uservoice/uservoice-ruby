# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "uservoice/version"

Gem::Specification.new do |s|
  s.name        = "uservoice-ruby"
  s.version     = Uservoice::VERSION
  s.authors     = ["Raimo Tuisku"]
  s.email       = ["dev@usevoice.com"]
  s.homepage    = "http://developer.uservoice.com"
  s.summary     = %q{Client library for UserVoice API}
  s.description = %q{The gem provides Ruby-bindings to UserVoice API and helps generating Single-Sign-On tokens.}

  s.rubyforge_project = "uservoice-ruby"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "rspec"
  s.add_runtime_dependency 'ezcrypto'
  s.add_runtime_dependency 'json'
  s.add_runtime_dependency 'oauth'
end
