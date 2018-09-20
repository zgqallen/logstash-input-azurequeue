Gem::Specification.new do |s|
  s.name          = 'logstash-input-azurequeue'
  s.version       = '0.1.0'
  s.licenses      = ['Apache-2.0']
  s.summary       = 'This plugin collects message from Microsoft Azure Storage Queue.'
  s.description   = 'This gem is a LogStash plugin. It read and parse dara from Azure Storage Queue.'
  s.homepage      = 'https://github.com/zgqallen/logstash-input-azurequeue'
  s.authors       = ['Zhong Guangqing']
  s.email         = 'gary.zhong@sap.com'
  s.require_paths = ['lib']

  # Files
  s.files = Dir['lib/**/*','spec/**/*','vendor/**/*','*.gemspec','*.md','CONTRIBUTORS','Gemfile','LICENSE','NOTICE.TXT']
   # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "input" }

  # Gem dependencies
  s.add_runtime_dependency "logstash-core-plugin-api", "~> 2.0"
  s.add_runtime_dependency 'logstash-codec-plain'
  s.add_runtime_dependency 'stud', '>= 0.0.22'
  s.add_development_dependency 'logstash-devutils', '>= 0.0.16'
  s.add_runtime_dependency 'azure-storage-queue', '>= 1.0.1'
  s.add_development_dependency 'logging', '~> 2' 
end
