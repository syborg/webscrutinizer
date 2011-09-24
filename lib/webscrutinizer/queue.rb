# Queue
# A class that enables queing jobs within Scrutinizer

module Webscrutinizer

  class Queue

    def initialize
      @queue=[]
    end

    # enqueues an element
    def deq
      @queue.shift
    end

    # enqueues an element
    def enq(element)
      @queue.push element
    end

    # true if there are elements in the queue
    def any?
      @queue.any?
    end

  end
  
end
