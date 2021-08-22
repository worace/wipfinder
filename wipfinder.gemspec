Gem::Specification.new do |s|
  s.name        = 'wipfinder'
  s.version     = '0.0.1'
  s.summary     = "Find uncommitted or unpushed git work."
  s.description = "A tool to help when migrating to a new machine."
  s.authors     = ["Horace Williams"]
  s.email       = 'horace@worace.works'
  s.files       = ["lib/wipfinder.rb"]
  s.homepage    = 'https://github.com/worace/wipfinder'
  s.license     = 'MIT'

  s.add_runtime_dependency 'git', '~> 1.9'
  s.add_runtime_dependency 'coque'
  s.executables << 'wipfinder'
end
