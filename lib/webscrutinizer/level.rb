# Level
# A class that contains main aspects to parse pages

module Webscrutinizer

  class Level

    attr_accessor :uri      # uri to go to a page
    attr_accessor :parrecs  # array of content parsers

    ParRec = Struct.new(:parser,:receiver)  # parser + receiver
    
    # Instantiates a Webscrutinizer::Level with +uri+ and a list of 
    # pairs parsers and receivers +pr+ interspersed
    def initialize(uri = nil, *pr, &block)
      @uri = uri
      @parrecs = []
      pr.each_slice(2) {|p,r| @parrecs << ParRec.new(p,r)}  if pr
      yield self if block_given?
    end

    # Adds a *parser* (to parse part or a whole page) and a *receiver* (to throw
    # all parser's results at) to a Level instance
    #
    # A *parser* is a symbol that refers to a process that, when called, should
    # return a hash like this:
    # {
    #   * +:CONTENT+ => if exists, it can contain either a
    #       - _hash_ (element) with details about an item
    #       - _array_ (list) of elements
    #
    #       Each element is a hash with key/value pairs that describe
    #       some attributes_ :FIELD1=>value1, :FIELD2=>value2, ...
    #       Some of them, however, have a special meaning and should not be used
    #       for any other attribute
    #       - +:_SUBLEVELS+ => if exist it may contain an _array_ of +Levels+
    #          that, normally, refine information about that element (but also
    #          it can be anything else, i.e. a list). These levels shoud be
    #          queued into the normal queue
    #
    #   * +:SIBLINGS+ => if exists, it can contain an _array_ of +Levels+ that,
    #      normally, leads into new pages with further lists (for instance
    #      following a "next" link). These levels will be queued into the
    #      priority queue.
    #
    #   * +:STATUS+ => if +:OK+ tells us that +:CONTENT+ and/or +:SIBLINGS+ are
    #      correctly fullfilled. Any other value (including _nil_) means that
    #      parsing hasn't been correctly done
    # }
    #
    # *receiver* can be either a reference to a hash (element) or array (list),
    # or a Symbol/String that identifies it by name. If nil, results should be
    # added to +:DEFAULT_LIST+ or +:DEFAULT_ELEM+ defined in Scrutinizer. if 
    # +:_SELF+ the result of the parser will be added to the current element or
    # the current list (wether the result is a hash or a list respectively)
    def use_parser parser, receiver=nil
      self.remove_parser parser
      @parrecs << ParRec.new(parser,receiver)
    end

    alias use use_parser
    alias add_parser use_parser
    alias add use_parser
    alias use_parrec use_parser
    alias add_parrec use_parser

    # if exists, removes +parser+ from the level and returns a _ParRec_ with
    # +parser+ and correspondent receiver, else nil
    def remove_parser parser
      res = nil
      @parrecs.delete_if do |p|
        res = p if p.parser == parser
      end
      res
    end

    alias remove remove_parser
    alias delete remove_parser

    # if exists, returns a _ParRec_ with +parser+ and its 
    # correspondent receiver, else returns nil
    def find_parser(parser)
      @parrecs.find { |p| p.parser == parser }
    end

    alias find find_parser
    

  end

end
