# SeedPool
# Marcel Massana 22-Sep-2011
#
# Engloba els levels inicials pels quals ha de arrencar el scrutinizer

require 'webscrutinizer/level'
#require 'yaml'

module Webscrutinizer

  class SeedPool

    attr_accessor :levels

    # SeedPool new constructor
    def initialize
      @levels = []
      yield self if block_given?
    end

    # Has +uri+ been included into the pool in some level?. Returns that level
    # if true, else nil.
    def find_level(uri)
      @levels.find {|lvl| lvl.uri == uri }
    end

    # Adds a +parser+ (and receiver) associated to an +uri+
    def use_parser(uri, parser, receiver=nil)
      # error checking
      raise ArgumentError, "Invalid URI" unless uri.is_a? String
      raise ArgumentError, "Invalid parser" unless parser.is_a? Symbol

      if (level=find_level uri)
        level.use_parser parser,receiver
      else
        @levels << Webscrutinizer::Level.new(uri, parser, receiver)
      end
    end

    alias add_parser use_parser
    alias seed use_parser

    # Removes a whole level corresponding to an +uri+ or a level's +parser+ if
    # +parser+ is given.
    def remove(uri, parser=nil)
      # error checking
      raise ArgumentError, "Invalid URI" unless uri.is_a? String
      if parser
        raise ArgumentError, "Invalid parser" unless parser.is_a? Symbol
      end

      if !parser
        @levels.delete_if { |l| l.uri == uri }
      elsif (level = find_level uri)
        level.remove_parser parser
      end

    end

    # returns an array with included URIs
    def uris
      arr = []
      self.each_uri {|u| arr << u}
      arr
    end

    # returns an array with parsers (symbols that identify them) assigned to 
    # parse +uri+
    def parsers(uri)
      lvl =  self.find_level(uri)
      lvl.parrecs.map(&:parser) if lvl
    end

    # ITERATORS

    # iterates over all levels yielding each one.
    def each_level(&block)
      @levels.each {|l| yield(l)}
    end

    # iterates over all levels yielding each URI.
    def each_uri(&block)
      @levels.each {|l| yield(l.uri)}
    end

  end

end

