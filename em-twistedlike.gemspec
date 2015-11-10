# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "em-twistedlike/version"

Gem::Specification.new do |s|
  s.name        = 'em-twistedlike'
  s.version     = EventMachine::TwistedLike::VERSION
  s.platform    = Gem::Platform::RUBY
  s.summary     = "EventMachine, the twisted way"
  s.description = "This Monkeypatch implement some of Twisted's Defer funtionnalities within EventMachine Deferrable"
  s.authors     = ["Nicolas AGIUS"]
  s.email       = 'nicolas.agius@lps-it.fr'
  s.files       = ["lib/em-twistedlike.rb"]
  s.homepage    = 'http://github.com/nagius/em-twistedlike'
  s.license     = 'GPL-3.0'
  s.add_runtime_dependency 'eventmachine', '~> 1.0'
end
