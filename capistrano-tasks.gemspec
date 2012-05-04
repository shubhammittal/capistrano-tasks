# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "capistrano-tasks/version"

Gem::Specification.new do |s|
  s.name        = "capistrano-tasks"
  s.version     = Capistrano::Tasks::VERSION
  s.authors     = ["Arnold Noronha"]
  s.email       = ["arnstein87@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Standard capistrano tasks for Rails apps, wee, and thrift services}
  s.description = %q{this is opiniated capistrano tasks, don't expect configurability}

  s.rubyforge_project = "capistrano-tasks"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_development_dependency "minitest"
  s.add_development_dependency "rake"

  # s.add_runtime_dependency "rest-client"
  s.add_runtime_dependency "capistrano"
end
