# test_seed_pool
# Marcel Massana 24-Sep-2011

lib = File.expand_path('../lib')
$: << lib unless $:.include? lib

require 'webscrutinizer/level'

require 'rubygems'
require 'minitest/autorun'


class TC_Level < Minitest::Test

  def setup
    @l = Webscrutinizer::Level.new "myuri" do |l|
      l.use_parser :PARSER_1, :RECEIVER_1
      l.use_parser :PARSER_2, :RECEIVER_2
    end
  end

  def test_use_parser_inexistent  # so it is added as the last one
    @l.use_parser :PARSER_3, :RECEIVER_3
    assert_equal [:PARSER_3, :RECEIVER_3], [@l.parrecs.last.parser, @l.parrecs.last.receiver]
  end

  def test_use_parser_replace_existent
    @l.use_parser :PARSER_2, :RECEIVER_3
    assert_equal [:PARSER_2, :RECEIVER_3], [@l.parrecs[1].parser, @l.parrecs[1].receiver]
  end

  def test_remove_parser_inexistent # should return nil
    assert_nil @l.remove_parser :PARSER_3
  end
  
  def test_remove_parser_existent_should_return_a_ParRec 
    assert_equal  :PARSER_2, (@l.remove_parser :PARSER_2).parser
  end
  
  def test_remove_parser_existent_should_delete_it 
    @l.remove_parser :PARSER_2
    assert_nil @l.parrecs[1]
  end
    
end
