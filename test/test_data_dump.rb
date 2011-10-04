# test_seed_pool
# Marcel Massana 29-Sep-2011

require 'rubygems'
require 'webscrutinizer/data_dump'
require 'test/unit'
require 'fileutils'

class TC_DataDump < Test::Unit::TestCase

  def setup
    @testdir='tmp_datadump'
    @item1= {'nom' => "Marcel", 'cognom' => "Massana", 'email' => "xaxaupua at gmail dot com"}
    @item2 = {'nom' => "Pep", 'cognom' => "Massana", 'email' => "fitxia at gmail dot com"}
    @item3 = [%w{marcel pep montse joana laia}, {'prova' => 'PROVA'}]
  end

  def teardown
    #FileUtils.rm_rf @testdir
  end

  def test_1_dump_list_into_list_default_format
    dd = Webscrutinizer::DataDump.new @testdir
    item = [@item1,@item2]
    receiver = :lists
    name = "llista_noms"
    dd.dump item, receiver, name
    read_item = nil
    File.open(dd.filepath(receiver, name),'r') { |f| read_item = YAML::load(f) }
    assert_equal item, read_item
  end

  def test_2_dump_list_into_list_ya2yaml
    dd = Webscrutinizer::DataDump.new @testdir, :ya2yaml
    item = [@item1,@item2]
    receiver = :lists
    name = "llista_noms"
    dd.dump item, receiver, name
    read_item = nil
    File.open(dd.filepath(receiver, name),'r') { |f| read_item = YAML::load(f) }
    assert_equal item, read_item
  end

  def test_4_dump_list_into_list_json
    dd = Webscrutinizer::DataDump.new @testdir, :json
    item = [@item1,@item2]
    receiver = :lists
    name = "llista_noms"
    dd.dump item, receiver, name
    read_item = nil
    File.open(dd.filepath(receiver, name),'r') { |f| read_item = Yajl::load(f) }
    assert_equal item, read_item
  end

  def test_5_dump_3_times_and_recover_default
    dd = Webscrutinizer::DataDump.new @testdir
    receiver = :lists
    name = "llista_noms"
    [@item1, @item2, @item3].each {|i| dd.dump(i,receiver,name)}
    read_item = nil
    File.open(dd.filepath(receiver, name),'r') { |f| read_item = YAML::load_stream(f).documents }
    assert_equal [@item1, @item2, @item3], read_item
  end

  def test_6_dump_3_times_and_recover_ya2yaml
    dd = Webscrutinizer::DataDump.new @testdir, :ya2yaml
    item1, item2 = {:nom => "Marcel", :cognom => "Massana", :email => "xaxaupua at gmail dot com"},
      {:nom => "Pep", :cognom => "Massana", :email => "fitxia at gmail dot com"}
    receiver = :lists
    name = "llista_noms"
    [@item1, @item2, @item3].each {|i| dd.dump(i,receiver,name)}
    read_item = nil
    File.open(dd.filepath(receiver, name),'r') { |f| read_item = YAML::load_stream(f).documents }
    assert_equal [@item1, @item2, @item3], read_item
  end

  def test_8_dump_3_times_and_recover_json
    dd = Webscrutinizer::DataDump.new @testdir, :json
    item1, item2 = {'nom' => "Marcel", 'cognom' => "Massana", 'email' => "xaxaupua at gmail dot com"},
      {'nom' => "Pep", 'cognom' => "Massana", 'email' => "fitxia at gmail dot com"}
    receiver = :lists
    name = "llista_noms"
    [@item1, @item2, @item3].each {|i| dd.dump(i,receiver,name)}
    read_item = []
    File.open(dd.filepath(receiver, name),'r') { |f| Yajl::Parser.parse(f) {|obj| read_item << obj } }
    assert_equal [@item1, @item2, @item3], read_item
  end

end
