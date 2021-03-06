# Scrutinizing Expedients de l'Ajuntament de Barcelona
# Marcel Massana 17-Sep-2011

lib = File.expand_path('../../lib')
$: << lib unless $:.include? lib

require './setup'
require 'yaml'
# aixo permet utilitzar .ya2yaml en comptes de .to_yaml, evitant les sortides
# binaries d'aquest posant-ho tot en ascii (escapant els utf8)
require 'ya2yaml'

# $KCODE = 'UTF8'

################
# Fakeweb Setup
#
unless @setup.online  # activate if not online
  # monkey patch for fakeweb. Mechanize#read_timeout doesn't work ?!?
  module FakeWeb
    class StubSocket
      def read_timeout=(*ignored)
      end
    end
  end
  FakeWeb.allow_net_connect=false # tots els accessos se simularan
  up=UriPathname.new :base_dir => @setup.pdump_dir, :file_ext=> ".html"
  dump_files = Dir[File.expand_path("*.html",@setup.pdump_dir)]
  dump_files.each do |f|
    uri = up.pathname_to_uri(f)
    FakeWeb.register_uri :any, uri, :body=>f, :content_type=>"text/html"
    #puts "#{uri} -> #{'OK' if FakeWeb.registered_uri?(:get, uri)}"
  end
  puts "Fakeweb: #{dump_files.size} URIs registered"
end
################

################
# Logger Setup
#
if @setup.log
  log1 = Logger.new(@setup.log_file,'weekly')
  log1.level = @setup.log_level
  log2 = Logger.new(File.expand_path("../tmp/mechanize.log",File.dirname(__FILE__)),'weekly')
  log2.level = @setup.log_level
end
################

#################
# WebDump Setup
# (save webpages)
if @setup.pdump
  wdumper=WebDump.new :base_dir => @setup.pdump_dir, :file_ext => @setup.pdump_ext
else
  wdumper=nil
end
#################

################
# DataDump Setup
# (save parsed data)
if @setup.ddump
  ddumper=Webscrutinizer::DataDump.new @setup.ddump_dir, @setup.ddump_format
else
  ddumper=nil
end

##################
# SimpleMap Setup
#
if @setup.lookup
  lookup=YAML.load_file(@setup.lookup_file)
  #  puts "LOOKUP:\n"
  #  p lookup.map
  #  p lookup.reverse_data.to_a.sort {|a,b| a.to_s <=> b.to_s}
  #  puts "\nDESCONEGUTS:\n"
  #  p lookup.unmapped_keys.to_a.sort {|a,b| a.to_s <=> b.to_s}
end
##################

######################
# ThreadedAgent Setup
#
agent=Webscrutinizer::ThreadedAgent.new :maxthreads => @setup.num_threads, :logger => log1
######################

#######################
# WebScrutinizer Setup
#
ws = Webscrutinizer::Scrutinizer.new(
  :lookup=>lookup,
  :agent=>agent,
  :log=>log1,
  :web_dump=> wdumper,
  :data_dump=> ddumper
) do |scr|

  #LEVELS
  scr.seed @setup.seeds.ANUNCIS_PREVIS, :LIST_PARSER, :ANUNCIS_PREVIS
  scr.seed @setup.seeds.ANUNC_LICIT, :LIST_PARSER, :ANUNC_LICIT
  scr.seed @setup.seeds.ADJUD_PROV, :LIST_PARSER, :ADJUD_PROV
  scr.seed @setup.seeds.ADJUD_DEF, :LIST_PARSER, :ADJUD_DEF
  scr.seed @setup.seeds.FORMALITZACIONS, :LIST_PARSER, :FORMALITZACIONS
  
  # PARSERS
  # parser de llistes de concursos
  scr.define_parser :LIST_PARSER do
    ret = {}
    exps = compose(@page.search(".concurs_esquerra_ordenant a"),@page.search(".concurs_dreta a")) do |itm1,itm2|
      exp, descr = itm2.content.gsub(/\s+/," ").scan(/(\S*) - (.*)/)[0]
      lnk = "http://w10.bcn.cat/APPS/gefconcursosWeb/"+itm2['href']
      sublvl = Webscrutinizer::Level.new do |l|
        l.uri = lnk
        l.use_parser :DETAIL_PARSER, :_SELF
      end
      {
        "exp" => exp.strip.upcase,
        "tipus" => itm1.text.strip,
        "lnk" => lnk,
        "descr" => descr,
        :_SUBLEVELS => [sublvl] # for further details
      }
    end
    # siblings?
    if (sblng = @page.at(".linkpaginacio")) && (sblng.content =~ /Seg/)
      # print_debug "SIBLING", sblng  # DEBUG
      lvl = Webscrutinizer::Level.new do |l|
        l.uri = "http://w10.bcn.cat/APPS/gefconcursosWeb/" << sblng["href"]
        l.use_parser :LIST_PARSER, :_SELF
      end
      ret.merge! :SIBLINGS => [lvl]
    end
    # return
    ret.merge! :CONTENT => exps
    ret
  end

  # parser de detalls dels concursos
  scr.define_parser :DETAIL_PARSER do
    details = compose(@page.search(".etiquetaCamps"), @page.search(".valorCamps")) do |clau, valor|
      if clau
        k = @lookup[clau.text.strip]
        v = valor.text.gsub(/\s+/," ").strip
        #print_debug 1, "#{k}: ", v, v.to_yaml if (k==:PRESSUPOST_IVA or k==:PRESSUPOST_BASE)
        {k => v}
      else
        {}
      end
    end.inject({}) {|ac,hsh| ac.merge! hsh if hsh}
    # adding links to documents
    docs = []
    @page.search("li a").each_with_index do |item, i|
      k=item.text.strip
      v="http://w10.bcn.cat/APPS/gefconcursosWeb/"+item['href']
      docs << {"nam" => k, "lnk" => v}
    end
    details["docs"]=docs unless docs.empty?
    # return
    {
      :CONTENT => details
    }
  end

end
#######################

###########################
# MAIN
###########################
ws.scrutinize #:maxpages => 25
              #:seeds => @setup.seeds.ADJUD_DEF
              
#ws.report
p ws.statistics
###########################

##################
# save parsed data
#
if @setup.saveparsed
  File.open(@setup.saveparsed_file,'w') do |f|
    YAML.dump(ws.receivers,f)
    #f.write ws.receivers.ya2yaml
  end
end

#####################
# SimpleMap Teardown
#
if @setup.lookup
  File.open(@setup.lookup_file,'w') do |f|
    YAML.dump(lookup,f)
    #f.write lookup.ya2yaml
  end
end
#####################

################
# Logger Teardown
#
if @setup.log
  log1.close
  log2.close
end
################
