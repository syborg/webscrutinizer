# Report
# Marcel Massana 29-09-2011
#
# Report methods

module Webscrutinizer

  # TODO perfeccionar aquest modul
  module Report

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

    private

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

  end
    
end
