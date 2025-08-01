$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'simplecov'
require 'dotenv/load'

# SimpleCov.minimum_coverage 95
SimpleCov.start

# This module is only used to check the environment is currently a testing env
module SpecHelper
end

require 'fastlane' # to import the Action super class
require 'fastlane/plugin/buildstash' # import the actual plugin

Fastlane.load_actions # load other actions (in case your plugin calls other actions or shared values)
