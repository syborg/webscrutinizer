# Printlog
# Marcel Massana 29-Sep-2011
#
# Enables convenient print_log method when included

module Webscrutinizer

  module Printlog

    private

    # Thread protected log: +mssg+ is the text to be logged and +logger_method+
    # is a symbol with the Logger object method to be called (:info, :warn,
    # :fatal, ...). See Logger.
    def print_log(logger_method, mssg)
      Thread.critical = true
      @log.__send__(logger_method, mssg)
      Thread.critical = false
    end
    
  end

end
