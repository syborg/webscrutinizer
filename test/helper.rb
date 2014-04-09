require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'minitest/autorun'

lib = File.expand_path('../lib')
$: << lib unless $:.include? lib

require 'webscrutinizer'

class Minitest::Test
end
