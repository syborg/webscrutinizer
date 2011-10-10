# Webscrutinizer
# Marcel Massana 10/9/2011

# includes generics
require 'rubygems'
require 'mechanize'
require 'yaml'
require 'logger'
require 'web_dump'
require 'mme_tools' # no public gem ...

# includes particulars
require 'webscrutinizer/error'
require 'webscrutinizer/version'
require 'webscrutinizer/simple_map'
require 'webscrutinizer/level'
require 'webscrutinizer/queue'
require 'webscrutinizer/threaded_agent'
require 'webscrutinizer/seed_pool'
require 'webscrutinizer/printlog'
require 'webscrutinizer/report'
require 'webscrutinizer/data_dump'
require 'webscrutinizer/helpers'

module Webscrutinizer

  include Webscrutinizer::Version

  # TODO investigar com aportar noves eines de parsejar adhoc (netejar adreces, etc) sense modificar la classe
  class Scrutinizer

    include MMETools::Enumerable # inclou compose, from_to, odd_values, even_values
    include MMETools::Debug # inclou print_debug
    include MMETools::ArgsProc

    include Webscrutinizer::Printlog
    include Webscrutinizer::Report
    include Webscrutinizer::Error
    include Webscrutinizer::Helpers

    attr_accessor :seedpool
    attr_accessor :parsers
    attr_reader :receivers
    attr_reader :statistics

    # INICIALITZACIO
    # TODO racionalitzar parametres d'inicialitzacio
    # lookup_map: objecte SimpleMap que s'usa per a simplificar els noms
    # de camps
    def initialize(opts={}, &block)
      # defaults
      options = {
        :lookup => SimpleMap.new, # mapa en el que buscar els noms de camps llegits
        :agent => ThreadedAgent.new, # navegador
        :depth => nil,
        :max_attempts => 3,
        :log => nil,
        :web_dump => nil,
        :data_dump => nil
      }
      assert_valid_keys opts, options
      options.merge! opts

      @lookup = options[:lookup]
      @agent = options[:agent]
      @max_attempts = options[:max_attempts]  # reintents que es vol fer al buscar una plana
      @log = options[:log]
      @web_dump = options[:web_dump]
      @data_dump = options[:data_dump]
      @page = nil

      # estructura on s'organitzen els Levels inicials per começar a scrutinitzar.
      @seedpool = SeedPool.new
      # hash de parsers. Cada key es un symbol identificatiu, i el valor es un
      # Process que es pot invocar amb Proc#call
      @parsers = {}
      # estructura on s'emmagatzema la informacio capturada
      @receivers = {
        :LISTS => {},     # contains named lists where lists can be accumulated
        :ELEMENTS => {},  # contains named hashes where named elements can be accumulated
        :DEFAULT_LIST => [],
        :DEFAULT_ELEMENT => {}
      }

      # main accumulators for speed metering
      @maxpages = nil   # maximum number of pages to process
      @total_pages = 0  # comptador de pagines

      @total_bytes = 0  # comptador de bytes
      @time_start = nil  # inici del scrutinize
      @time_stop = nil # final del scrutinize
      
      @statistics = {} # hash per a guardar estadistiques

      # cues per recorrer les pagines Breadth-First
      @queue_normal = Queue.new     # levels normals
      @queue_priority = Queue.new   # levels siblings
      @queue_hndl = []  # s'encuen els levels que es van solicitant als threaded
      
      yield self if block_given?

    end

    # TODO detectar si s'entra en un bucle (detectar si una URI es visita 2 cops)
    # @todo parametritzarlo per a que admeti recorrer un nombre determinat de pagines
    # per maxim nombre de pagines,
    # per profunditat,
    # per indicacio de llista/adreça/..
    # @todo canviar @page de Mechanize::Page (estructura propia del mechanize)
    # @todo estudiar alguna manera de permetre guardar els resultats mentre es
    # navega en comptes de tenir-ho tot en memoria (memcached, ...)
    # per un String que sigui el HTML de la pàgina
    #
    # scrutinize is the spider engine that traverses webpages and captures
    # information. +opts+ is a Hash that configures the traverse behaviour.
    # It may contain:
    #   :seeds => nil (default) -> Initiates scrutinizing of everything in the SeedPool
    #             "any_uri" (String) -> Initiates scrutinizing only in "any_uri" that should already been included in a seed in SeedPool. Doesn't do anything if it doesn't exist.
    #             ["uri1", "uri2", ...] (Array) -> Initiates scrutinizing only in those uris included in the array that are also contained in the SeedPool.
    #             anything else is silently ignored
    #   :maxpages => nil (default) -> scrutinizes all possible pages
    #                num (Integer) -> Stops when scrutinizer reaches _num_ pages (and possibly some more if there are threaded agents yet fetching) or there are no more pages to follow.
    #
    def scrutinize(opts={})
      options = {:seeds => nil, :maxpages => nil}
      assert_valid_keys opts, options
      options.merge! opts

      # options[:maxpages]
      if @maxpages = options[:maxpages]
        raise Webscrutinizer::Error::BadOption, ":maxpages should be a positive integer or nil" unless @maxpages.is_a?(Integer) && @maxpages > 0
      end

      @total_pages = 0

      @time_start = Time.now
      @total_bytes = 0
      print_log(:info, "---- SCRUTINIZE BEGIN ----") if @log

      # options[:seeds]
      # 1: enqueue seed levels given in opts[:seeds]
      enqueue_seeds options[:seeds]
      
      begin

        # 2: dequeues elements from queues with priority for siblings
        # (new elements are enqueued implicitly by parsers)
        lvl = dequeue_level

        # 3: if a new level keep trying to fetch it (don't try another uri until
        # this is done)
        if lvl
          quit = false
          until hndl=@agent.t_get(lvl.uri)  # keep hndl for further references
            # to this thread
            # 4: while not able to fetch try to process once all pending pages
            pending_pages
          end
          @queue_hndl << [lvl,hndl]
          #print_debug 0, "Encomanat #{hndl}. @queue_hndl queda ...", @queue_hndl
        
          # 5: else try to process once the rest of pending pages
        else
          if pending_pages > 0
            quit = false
          elsif @queue_priority.any? || @queue_priority.any?
            quit = false
          else
            quit = true
          end
        end

        if @maxpages
          quit = true if @total_pages >= @maxpages
        end

      end until quit

      # FIXME dumping data should be done while parsing. This is only a temporary solution
      dump_all_receivers
      
      @time_stop = Time.now
      print_log(:info, "#{@total_pages} Pages: #{@total_bytes} B in #{sprintf('%d',t=(@time_stop - @time_start))} s = #{sprintf('%d',@total_bytes/t)} Bps ") if @log
      print_log(:info, "---- SCRUTINIZE END ----") if @log
    end

    # calls all parsers for that level (assuming that @page contains data) and
    # enqueues further siblings and sublevels if there exist.
    def process_level(level)

      level.parrecs.each do |parrec|

        # print_debug 1, "PARSERS", level.parrecs
        
        print_log(:info, "Parsing with #{parrec.parser}") if @log
        add_one_to :PARSE_COUNT

        res = @parsers[parrec.parser].call
        content = res[:CONTENT]
        rcvr = parrec.receiver

        # if there are siblings they'll have priority
        res[:SIBLINGS].each do |sblng|  # sblng es un Level
          sblng.parrecs.each do |p|
            p.receiver = rcvr if (p.receiver == :_SELF)
          end
          @queue_priority.enq sblng
        end if res.has_key? :SIBLINGS

        case content
        when Hash   # element
          process_element content, rcvr
        when Array  # list
          process_list content, rcvr
        else
          # error: bad content
        end
      end
    end

    # Process an element
    def process_element(element, rcvr)
      add_one_to :ELEMENTS_COUNT
      # if exist sublevels enqueue them and delete that key/value pair
      enq_sublevels element
      case rcvr
      when Symbol, String # named receiver
        ereceivers=@receivers[:ELEMENTS]
        if ereceivers.has_key? rcvr
          ereceivers[rcvr].merge! element
        else
          ereceivers[rcvr] = element
        end
      when Hash           # refered receiver
        rcvr.merge! element
      when nil            # no receiver
        @receivers[:DEFAULT_ELEMENT].merge! element
      else
        # error: bad receiver
      end
    end

    # Process a list
    def process_list(list, rcvr)
      # mirem si hi ha sublevels a cada element
      list.each do |e|
        enq_sublevels e
      end

      case rcvr
      when Symbol, String # named receiver
        lreceivers=@receivers[:LISTS]
        if lreceivers.has_key? rcvr
          lreceivers[rcvr] += list
        else
          lreceivers[rcvr] = list
          self.add_one_to :LISTS_COUNT
        end
      when Array          # refered receiver
        rcvr += list
      when nil            # no receiver
        @receivers[:DEFAULT_LIST] += list
      else
        # error: bad receiver
      end
    end

    # looks for sublevels in +element+ and enqueue them for further process
    def enq_sublevels(element)
      if element.has_key? :_SUBLEVELS
        # substitute :_SELF receivers by actual current element
        element[:_SUBLEVELS].each do |slvl|
          slvl.parrecs.each do |p|
            p.receiver = element if (p.receiver == :_SELF)
          end
          @queue_normal.enq slvl
        end
        element.delete :_SUBLEVELS
      end
    end

    # Adds one to a counter +cref+
    def add_one_to(cref)
      if @statistics.has_key? cref
        @statistics[cref] +=1
      else
        @statistics[cref] =1
      end
    end

    # Dona d'alta dins de _@parsers_ un nou parser amb nom +name+
    # El +block+ passat es un codi que s'executarà dins de l'objecte
    # scrutinizer (self), per tant, amb tots els seus mètodes disponibles.
    # Si el +block+, a mes a mes, accepta arguments, aleshores aquest
    # parser pot reutilitzarse per formar part de nous parsers amb
    # el metode *define_on_parser*. Els parametres a passar son a gust
    # de l'usuari, tot i que es recomana un hash (on es poden
    # definir nominalment multitut de valors)
    # +name+ es el nom (per exemple un symbol) del nou parser
    # +block+ es el bloc de codi que conforma el parser
    def define_parser(name, &block)
      # rt_args (run time args) permet cridar al parser amb parametres despres
      # (sempre que block els accepti tambe).
      @parsers[name] = Proc.new { |*rt_args| instance_exec(*rt_args, &block) } if block_given?
    end

    # Dona d'alta un nou parser amb nom +name+ que cridara al parser de nom
    # +used_parser+ passant-li els arguments +args+
    def define_on_parser(name, used_parser, *args)
      @parsers[name] = Proc.new { @parsers[used_parser].call(*args) }
    end

    # Adds new uris and corresponding parsers to initiate spidering
    def seed(uri,parser,receiver)
      @seedpool.seed(uri,parser,receiver)
    end

    ###########################################################################
    private
    
    # Tries to retrieve and process all pages that have already been fetched
    # with ThreadedAgent#t_get(uri) but not yet received. Returns the number of
    # pending pages.
    def pending_pages
      @queue_hndl.each_with_index do |pair, i|
        l, h = pair # [level, handle]
        if @page=@agent.t_get(h) # @page refers to the page to be
          # parsed (as seen by all parsers)
          #print_debug 0, "Processant (1) handle #{h}"
          if @page != ""  # "" indicates unavoidable error
            @total_bytes += @page.content.size
            @total_pages += 1
            @web_dump.save(@page.uri.to_s, @page.content.to_s) if @web_dump
            print_log(:info, "TA##{h} Received Page OK") if @log
            process_level(l)
          end
          @queue_hndl.delete_at(i) # delete pair i
        end
      end
      @queue_hndl.size
    end

    # enqueues seed levels that will be traversed given +opt+ (see scrutinize)
    def enqueue_seeds opt
      case opt
      when nil  # everything will be scrutinized
        @seedpool.each_level do |lvl|
          @queue_normal.enq lvl
        end
      when String
        lvl = @seedpool.find_level(opt)
        @queue_normal.enq lvl if lvl
      when Array
        opt.each do |uri|
          lvl = @seedpool.find_level(uri)
          @queue_normal.enq lvl if lvl
        end
      end
    end

    # gets a level from the correct (priorized) queue. returns a
    # Webscrutinizer::Level if it exists or nil if it doesn't.
    def dequeue_level
      if @queue_priority.any?
        lvl = @queue_priority.deq
      elsif @queue_normal.any?
        lvl = @queue_normal.deq
        #      else
        #        nil
      end
    end

    # dumps al parsed data within @receivers by means of @data_dump object
    def dump_all_receivers
      if @data_dump
        # LISTS
        @receivers[:LISTS].each do |lkey,list|
          list.each do |elem|
            @data_dump.dump(elem, :lists, lkey.to_s) unless elem.empty?
          end
        end
        # ELEMENTS
        @receivers[:ELEMENTS].each do |ekey,elem|
          @data_dump.dump(elem, :elements, ekey.to_s) unless elem.empty?
        end
        # DEFAULT_LIST
        @receivers[:DEFAULT_LIST].each do |elem|
          @data_dump.dump(elem, :default_list) unless elem.empty?
        end
        # DEFAULT_ELEMENT
        elem = @receivers[:DEFAULT_ELEMENT]
        @data_dump.dump elem, :default_element unless elem.empty?
      end
    end

  end

end
