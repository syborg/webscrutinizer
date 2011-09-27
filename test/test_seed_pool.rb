# test_seed_pool
# Marcel Massana 24-Sep-2011

require 'webscrutinizer/seed_pool'
require 'test/unit'


class TC_SeedPool < Test::Unit::TestCase

  def setup
    @sp = Webscrutinizer::SeedPool.new do |sp|
      sp.levels << Webscrutinizer::Level.new do |l|
        l.uri = "uri1"
        l.use_parser :PARSER_1_1, :LIST_1_2
        l.use_parser :PARSER_1_2, :LIST_1_2
      end
      sp.levels << Webscrutinizer::Level.new do |l|
        l.uri = "uri2"
        l.use_parser :PARSER_2, :LIST_2
      end
    end
  end

  def test_find_level_that_exists
    assert @sp.find_level("uri2")
  end

  def test_find_level_that_doesnt_exist
    assert_nil @sp.find_level("inexistant_uri")
  end

  def test_use_parser_that_exists
    @sp.use_parser("uri1", :PARSER_1_1, :LIST_NEW)
    assert_equal :LIST_NEW, @sp.find_level("uri1").find_parser(:PARSER_1_1).receiver
  end

  def test_use_parser_that_doesnt_exist
    @sp.use_parser("uri1", :PARSER_NEW, :LIST_NEW)
    assert_equal :LIST_NEW, @sp.find_level("uri1").find_parser(:PARSER_NEW).receiver
  end

  def test_remove_whole_level
    @sp.remove "uri1"
    assert_nil @sp.find_level("uri1")
  end

  def test_remove_only_a_parser
    @sp.remove "uri1", :PARSER_1_2
    assert_nil @sp.find_level("uri1").find_parser(:PARSER_1_2)
  end

  def test_uris
    assert_equal(%w[uri1 uri2], @sp.uris)
  end

  def test_parsers_of_existent_uri
    assert_equal([:PARSER_1_1, :PARSER_1_2], @sp.parsers("uri1"))
  end

  def test_parsers_of_inexistent_uri
    assert_nil @sp.parsers("inexistent_uri")
  end

  def test_each_uri
    arr =[]
    @sp.each_uri {|u| arr << u}
    assert_equal ["uri1","uri2"], arr
  end

  def test_each_level
    arr =[]
    @sp.each_level {|l| arr << l}
    assert_instance_of(Webscrutinizer::Level, arr[1])
  end
  
end
