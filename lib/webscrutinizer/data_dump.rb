# DataDump
# Marcel Massana 29-Sep-2011
#
# Provides a wrapper around some ways to save Scrutinizer data in chunks, i.e.
# lists and elements

require 'rubygems'
require 'yajl'
require 'yaml'
require 'ya2yaml'
require 'webscrutinizer/error'

$KCODE = 'UTF8'

module Webscrutinizer

  # Dumps Webscrutinizer::Scrutinizer#receivers data into files.
  class DataDump

    include Webscrutinizer::Error

    FNAMES = {
      :lists => 'lists/',       # Directory where LISTS will be dumped
      :elements => 'elements/', # Directory where ELEMENTS will be dumped
      :default_list => 'default_list',      # file where DEFAULT_LIST will be dumped
      :default_element => 'default_element' # file where DEFAULT_ELEMENT will be dumped
    }

    # creates a DataDump object.
    # +dir+ is a directory where data will be dumped.
    # +format+ can be
    #   :yaml (default) ->  uses .to_yaml to serialize data
    #   :ya2yaml -> uses .ya2yaml to serialize data
    #   :json -> uses Yajl::Encoder to serialize data (symbols will be back recovered as strings)
    #   for anyother value :yaml will be assumed
    def initialize(dir, format=nil)
      @format = format
      @extension = case format
      when :ya2yaml then '.yml'
      when :json then '.json'
      else '.yml'
      end

      @dir = File.expand_path(dir)
      @files = [] # keeps names of already created files
    rescue
      raise Webscrutinizer::Error::BadArgument, "Invalid dir #{dir}"
    end

    # dumps +item+ that pertanins to the +receiver+ type named after +name+
    #   +item+ can be any object
    #   +receiver+ should be any of these symbols
    #     :lists -> +name+ indicates the (file)name of the list
    #     :elements -> +name+ indicates the (file)name of the element
    #     :default_list -> +name+ isn't used
    #     :default_element -> +name+ isn't used
    #
    # Example
    #
    #   <code>dump({:name=>"Marcel"},:lists,'name_list')</code>
    #
    def dump(item, receiver, name=nil)
      raise Webscrutinizer::Error::BadArgument, "Invalid receiver" unless FNAMES.keys.include? receiver
      raise Webscrutinizer::Error::BadArgument, "Invalid name" unless (name.nil? || name.is_a?(String))

      fp = filepath(receiver, name)
      mkdir_if_not_exists File.dirname(fp)
      create_file_if_first_access(fp)

      File.open(fp, 'a') do |f|
        f.write case @format
        when :ya2yaml then item.ya2yaml
        when :json then Yajl::Encoder.encode item
        else item.to_yaml
        end
      end
    end

    # creates a filepath for that receiver and name as of #dump
    def filepath(receiver, name)
      case receiver
      when :lists, :elements then File.join(@dir,FNAMES[receiver],name+@extension)
      when :default_list, :default_element then File.join(@dir,FNAMES[receiver]+@extension)
      else File.join(@dir,'ERRORS'+@extension)
      end
    end

    private

    # creates +directory+ if it doesn't exist
    def mkdir_if_not_exists(dir)
      FileUtils.mkdir_p(dir) unless (File.exist?(dir) and File.directory?(dir))
    rescue
      raise Webscrutinizer::Error::BadArgument, "Invalid dir #{dir}"
    end

    def create_file_if_first_access(fp)
      unless @files.include? fp
        FileUtils.rm fp, :force => true
        FileUtils.touch fp
        @files << fp
      end
    end

  end
    
end
