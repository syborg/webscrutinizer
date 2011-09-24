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
require 'webscrutinizer/version'
require 'webscrutinizer/simple_map'
require 'webscrutinizer/level'
require 'webscrutinizer/queue'
require 'webscrutinizer/threaded_agent'

module Webscrutinizer

  include Webscrutinizer::Version

  # @todo investigar com aportar noves eines de parsejar adhoc (netejar adreces, etc) sense modificar la classe
  class Scrutinizer

    include MMETools::Enumerable # inclou compose, from_to, odd_values, even_values
    include MMETools::Debug # inclou print_debug

    attr_accessor :receivers
    attr_accessor :levels
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
          :web_dump => nil
      }
      unknown_keys = opts.keys - options.keys
      raise(ArgumentError, "Unknown options(s): #{unknown_keys.join(", ")}") unless unknown_keys.empty?
      options.merge! opts

      @lookup = options[:lookup]
      @agent = options[:agent]
      @max_attempts = options[:max_attempts]  # reintents que es vol fer al buscar una plana
      @log = options[:log]
      @web_dump = options[:web_dump]
      @page = nil

      # estructura on s'emmagatzema la informacio capturada
      @receivers = {
        :LISTS => {},     # this hash contains named lists where lists can be accumulated
        :ELEMENTS => {},  # this hash contain named hasehs where named elements can be accumulated
        :DEFAULT_LIST => [],
        :DEFAULT_ELEMENT => {}
      }
      
      # main accumulators for speed metering
      @total_bytes = 0  # acumulador de bytes
      @time_start = nil  # inici del scrutinize
      @time_end = nil # final del scrutinize
            
      @levels = [] # array on hi van els arbres de parsejat ... (segurament a modificar)
      @parsers = {} # hash de parsers
      @statistics = {} # hash per a guardar estadistiques

      # cues per recorrer les pagines Breadth-First
      @queue_normal = Queue.new     # levels normals
      @queue_priority = Queue.new   # levels siblings
      @queue_hndl = []  # s'encuen els levels que es van solicitant als threaded
      
      yield self if block_given?

    end

    # @todo parametritzarlo per a que admeti recorrer un nombre determinat de pagines
    # per maxim nombre de pagines,
    # per profunditat,
    # per indicacio de llista/adreça/..
    # @todo canviar @page de Mechanize::Page (estructura propia del mechanize)
    # @todo estudiar alguna manera de permetre guardar els resultats mentre es
    # navega en comptes de tenir-ho tot en memoria (memcached, ...)
    # per un String que sigui el HTML de la pàgina
    def scrutinize
      @time_start = Time.now
      @time_end = nil
      @total_bytes = 0
      print_log(:info, "---- SCRUTINIZE BEGIN ----") if @log
      # 1: enqueue all seed levels
      levels.each do |lvl|
        @queue_normal.enq lvl
      end
      
      loop do

        lvl=nil
        quit=true

        # 2: dequeues elements from queues with priority for siblings
        # (new elements are enqueued implicitly by parsers)
        if @queue_priority.any?
          quit=false
          lvl = @queue_priority.deq
        elsif @queue_normal.any?
          quit=false
          lvl = @queue_normal.deq
        end

        # 3: if a new level keep trying to fetch it (don't try another uri until
        # this is done)
        if lvl
          quit = false
          until hndl=@agent.t_get(lvl.uri)  # keep hndl for further references
            # to this thread
            # 4: while not able to fetch try to process once all pending pages
            @queue_hndl.each_with_index do |pair, i|
              l, h = pair # [level, handle]

              if @page=@agent.t_get(h) # @page refers to the page to be 
                # parsed (as asumed by all parsers)
                #print_debug 0, "Processant (1) handle #{h}"
                if @page != ""  # "" indicates unavoidable error
                  @total_bytes += @page.content.size
                  @web_dump.save(@page.uri.to_s, @page.content.to_s) if @web_dump
                  print_log(:info, "TA##{h} Received Page OK") if @log
                  process_level(l)
                end
                @queue_hndl.delete_at(i) # delete pair i
              end
            end
          end
          @queue_hndl << [lvl,hndl]
          #print_debug 0, "Encomanat #{hndl}. @queue_hndl queda ...", @queue_hndl
        
          # 5: else try to process the rest of pending pages
        else
          @queue_hndl.each_with_index do |pair, i|
            quit = false
            l, h = pair
            #print_debug 0, "Processant (2) handle #{i}", pair, @queue_hndl.size
            if @page=@agent.t_get(h) # @page refers to the page to be
              # parsed (as asumed by all parsers)
              if @page != ""  # "" indicates unavoidable error
                @total_bytes += @page.content.size
                @web_dump.save(@page.uri.to_s, @page.content.to_s) if @web_dump
                print_log(:info, "TA##{h} Received Page OK") if @log
                process_level(l)
              end
              #print_debug 0, "Esborrant @queue_hndl[#{i}]"
              @queue_hndl.delete_at(i) # delete pair i
            end
          end
        end
        break if quit
      end
      @time_stop = Time.now
      print_log(:info, "#{@total_bytes} B in #{sprintf('%d',t=(@time_stop - @time_start))} s = #{sprintf('%d',@total_bytes/t)} Bps ") if @log
      print_log(:info, "---- SCRUTINIZE END ----") if @log
    end

    def process_level(level)

      level.parsers.each do |parser|

        print_log(:info, "Parsing with #{parser[:PARSER]}") if @log
        self.add_one_to :PARSE_COUNT

        res = @parsers[parser[:PARSER]].call
        parser[:RESULT] = res
        content = res[:CONTENT]
        rcvr = parser[:RECEIVER]

        # if there are siblings they'll have priority
        res[:SIBLINGS].each do |sblng|  # sblng es un Level
          sblng.parsers.each do |p|
            p[:RECEIVER] = rcvr if (p[:RECEIVER] == :_SELF)
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
      self.add_one_to :ELEMENTS_COUNT
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
          slvl.parsers.each do |p|
            p[:RECEIVER] = element if (p[:RECEIVER] == :_SELF)
          end
          @queue_normal.enq slvl
        end
        element.delete :_SUBLEVELS
      end
    end

    # jumps to a new uri (deprecated from the Threaded version)
    def change_to(obj, what=:URI)
      attempt=0
      print_log(:info, "Visiting #{obj}") if @log
      self.add_one_to :PAGE_COUNT
      begin
        case what
        when :URI
          @page = @agent.get obj
        when :LNK
          @page = obj.click
        else
          raise "Unknown what"
        end
      rescue => err
        if attempt <= @max_attempts
          print_log(:warn, "Attempt #{attempt}: #{err}") if @log
          attempt += 1
          retry
        else
          print_log(:fatal, "Impossible connection: #{err}") if @log
          return nil
        end
        # Timeout::Error no es caça i s'ha de posar explicitament
        # veure http://lindsaar.net/2007/12/9/rbuf_filltimeout-error
      rescue Timeout::Error => err
        if attempt <= @max_attempts
          print_log(:warn, "Timeout: Attempt #{attempt}: #{err}") if @log
          attempt += 1
          retry
        else
          print_log(:fatal, "Timeout: Impossible connection: #{err}") if @log
          return nil
        end
      end
      @page
    end

    # outputs the contents of @receivers, i.e. all extracted data
    def report
      # default element first
      report_element @receivers[:DEFAULT_ELEMENT], "DEFAULT_ELEMENT"
      # other elements
      hshs = @receivers[:ELEMENTS]
      if !hshs.empty?
        puts ">>> OTHER ELEMENTS"
        hshs.each do |k,e|
          report_element e, k.to_s
        end
        puts "<<< OTHER ELEMENTS"
      end
      # default list
      report_list @receivers[:DEFAULT_LIST], "DEFAULT_LIST"
      # other lists
      hshs = @receivers[:LISTS]
      if !hshs.empty?
        puts ">> OTHER LISTS"
        hshs.each do |k,e|
          report_list e, k.to_s
        end
        puts "<< OTHER LISTS"
      end
    end

    # reports an +element+ (hash) with name +name+
    def report_element(element, name)
      if !element.empty?
        nspc = name.to_s[/\s+/]
        nspc = nspc ? nspc.length : 0
        puts ">#{name}"
        element.sort_by{|a,b| a.to_s}.each do |itm|
          puts "#{' '*(nspc+1)}#{itm[0]}: #{itm[1]}"
        end
        puts "<#{name}"
      end
    end

    # reports a +list+ (array) with name +name+
    def report_list (list, name)
      if !list.empty?
        nspc = name.to_s[/\s+/]
        nspc = nspc ? nspc.length : 0
        puts ">>#{name}"
        list.each_with_index do |element,i|
          report_element element, "#{' '*(nspc+1)}ELEMENT #{i}"
        end
        puts "<<#{name}"
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
      # check argument errors
      raise ArgumentError, "Invalid URI" unless uri.is_a? String
      raise ArgumentError unless parsers.all? {|p| p.is_a? Symbol}
      
      level = Level.new do |l|
        l.uri = uri
        l.use_parser parser,receiver
      end
      self.levels << level
    end

    private

    # thread protected log:
    # +mssg+ is the text to be logged and +logger_method+
    # is a symbol with the Logger object method to be called (:info, :warn,
    # :fatal, ...)
    def print_log(logger_method, mssg)
      Thread.critical = true
      @log.__send__(logger_method, mssg)
      Thread.critical = false
    end

  end

end