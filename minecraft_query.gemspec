# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'minecraft_query/version'

Gem::Specification.new do |spec|
  spec.name          = "minecraft_query"
  spec.version       = MinecraftQuery::VERSION
  spec.authors       = ["Vladimir Kochnev"]
  spec.email         = ["hashtable@yandex.ru"]

  spec.summary       = %q{UDP client for Minecraft Query Protocol}
  spec.description   = %q{UDP client for Minecraft Query Protocol}
  spec.homepage      = "https://github.com/marshall-lee/minecraft_query"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.8"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "eventmachine"
end
