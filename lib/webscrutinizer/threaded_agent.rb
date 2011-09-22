# ThreadedAgent
# Marcel Massana 10-Aug-2011

require 'rubygems'
require 'mme_tools'
require 'mechanize'

module Webscrutinizer

  # Allows to navigate through several pages in a parallel way
  # @todo add other possibilities (verbs): put, delete, post
  class ThreadedAgent

    include MMETools::Debug
    include MMETools::Concurrent
    include MMETools::ArgsProc
    
    attr_accessor :agents
    attr_accessor :threads
    attr_accessor :retvals
    attr_accessor :time_start
    attr_accessor :time_stop

    # Called when instantiating a ThreadedAgent
    # +agent_type+ is a symbol that can be:
    #   _:mechanize_ to use Mechanize agents
    # +options+ is a hash:
    #   +:maxthreads => maxthreads+ is the maximum number of threads (default 1)
    #   +:maxattempts => maxattempts+ maximum number of attempts before giving up
    #   +:logger => logger+ Logger object to log running info
    def initialize(opts={})

      options = {
        :maxthreads => 1,
        :maxattempts => 3,
        :logger => nil,
      }
      assert_valid_keys opts, options
      options.merge! opts
      @maxthreads = options[:maxthreads]
      @maxattempts = options[:maxattempts]
      @log = options[:logger]

      @agents=ConcurrentArray.new
      @retvals=ConcurrentArray.new
      @threads=ConcurrentArray.new
      @time_start=ConcurrentArray.new
      @time_stop=ConcurrentArray.new
      (0...@maxthreads).each do |i|
        @agents << Mechanize.new do |a| 
          a.read_timeout = 20 # No funciona amb el stub fakeweb
          a.max_history = 1 
        end
        # placeholders for future threads
        @retvals << nil
        @threads << nil 
        @time_start << nil
        @time_stop << nil
      end
      @next_av=0 # will enable rotation through arrays
    end

    # returns a handle if there is a free agent that can be used or nil if it
    # isn't
    def available?
      (0...@maxthreads).each do |i|
        j = (@next_av+i) % @maxthreads
        if @threads[j].nil?
          @next_av = (j+1) % @maxthreads
          return j
        end
      end
      nil
    end

    # @todo manage and recover from errors
    #  t_get is a threaded get: works in 2 -non waiting- phases
    # *1st phase:* if +val+ is a URI (String class) it tries to spawn a thread
    # with an agent trying to _get_ that uri and returns a handle (Integer)
    # for further reference. If not possible returns nil.
    # *2nd phase:* if +val+ is a handle (Integer) the result of the agent's
    # (_page_) is returned, _""_ to indicate an error and _nil_ if it isn't yet 
    # available
    def t_get(arg)
      case arg
      when String # uri string
        if i=available?
          #print_debug(0,"Available handle #{i}")
          thr = Thread.new do
            #print_debug(0,"Inside Thread with handle #{i}")
            @time_start[i]=Time.now
            attempt=1
            print_log(:info, "TA##{i} Visiting #{arg}") if @log
            #print_debug(1,"Visiting #{arg}")
            begin
              @retvals[i]=agents[i].get arg
            rescue => err
              print_log(:fatal, "TA##{i} Impossible connection: #{err.class}: #{err}") if @log
              #print_debug(1,"Impossible connection: #{err}")
              @retvals[i]=""  # indicates error 
              return nil
            # Timeout::Error no es caça i s'ha de posar explicitament
            # veure http://lindsaar.net/2007/12/9/rbuf_filltimeout-error
            rescue Timeout::Error => err
              if attempt <= @maxattempts
                print_log(:warn, "TA##{i} Timeout: Attempt #{attempt}: #{err.class}: #{err}") if @log
                #print_debug(1, "Timeout: Attempt #{attempt}: #{err}")
                attempt += 1
                retry
              else
                print_log(:fatal, "TA##{i} Timeout: Impossible connection: #{err.class}: #{err}") if @log
                #print_debug(1, "Timeout: Impossible connection: #{err}")
                @retvals[i]=""  # indicates error 
                return nil
              end
            ensure 
              @time_stop[i]=Time.now
            end
          end
          @threads[i] = thr
          i
        end
      when Integer  # handle
        # print_debug 1, "t_get amb Integer #{arg}", @threads
        if @threads[arg].alive?
          return nil
        else
          @threads[arg]=nil
          @retvals[arg]
        end

      else # error
        nil
      end
    end

    private
    
    # thread protected log: +mssg+ is the text to be logged and +logger_method+
    # is a symbol with the Logger object method to be called (:info, :warn, 
    # :fatal, ...). See Logger.
    def print_log(logger_method, mssg)
      Thread.critical = true
      @log.__send__(logger_method, mssg)
      Thread.critical = false
    end

  end

end