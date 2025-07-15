source('https://rubygems.org')

gem 'abbrev'
gem 'logger'
gem 'mutex_m'
gem 'ostruct'

gemspec

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)

gem "dotenv", "~> 2.8"
