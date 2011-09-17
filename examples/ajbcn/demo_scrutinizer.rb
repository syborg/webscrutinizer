# Scrutinizing Expedients de l'Ajuntament de Barcelona
# Marcel Massana 17-Sep-2011

require './setup'

################
# FAKEWEB Setup
################
unless @setup.online  # activate if not online
  # monkey patch for fakeweb. Mechanize#read_timeout doesn't work ?!?
  module FakeWeb
    class StubSocket
      def read_timeout=(*ignored)
      end
    end
  end
  FakeWeb.allow_net_connect=false # tots els accessos se simularan
  up=UriPathname.new :base_dir => @setup.dump_dir, :file_ext=> ".html"
  dump_files = Dir[File.join(@setup.dump_dir,"*.html")]
  dump_files.each do |f|
    uri = up.pathname_to_uri(f)
    FakeWeb.register_uri :any, uri, :body=>f, :content_type=>"text/html"
    #puts "#{uri} -> #{'OK' if FakeWeb.registered_uri?(:get, uri)}"
  end
  puts "Fakeweb: #{dump_files.size} URIs registered"
end
################

################
# Loggers Setup
################
if @setup.log
  log1 = Logger.new(@setup.log_file,'weekly')
  log1.level = @setup.log_level
  log2 = Logger.new(File.expand_path("../tmp/mechanize.log",File.dirname(__FILE__)),'weekly')
  log2.level = Logger::DEBUG
end
################

#################
# WebDump Setup
#################
if @setup.dump
  wdumper=WebDump.new :base_dir => @setup.dump_dir, :file_ext => @setup.dump_ext
else
  wdumper=nil
end
#################

##################
# SimpleMap Setup
##################
if @setup.lookup
  LOOKUP_FILE=@setup.lookup_file
#  puts "LOOKUP:\n"
#  p lookup.map
#  p lookup.reverse_data.to_a.sort {|a,b| a.to_s <=> b.to_s}
#  puts "\nDESCONEGUTS:\n"
#  p lookup.unmapped_keys.to_a.sort {|a,b| a.to_s <=> b.to_s}
end
##################

##################
# Parsed Data Dump Setup
##################
if @setup.saveparsed
  EXP_FILE=@setup.saveparsed_file
end
##################

################
# Threaded Agent
################
agent=Webscrutinizer::ThreadedAgent.new :maxthreads => 12, :logger => log1
################

ws = Webscrutinizer::Scrutinizer.new(lookup, agent, nil, 3, log1, wdumper) do |scr|

  #LEVELS
  scr.levels << Webscrutinizer::Level.new do |l|
    l.uri = SEEDS[:ANUNCIS_PREVIS]
    l.use_parser :LIST_PARSER, :ANUNCIS_PREVIS
  end

  scr.levels << Webscrutinizer::Level.new do |l|
    l.uri = SEEDS[:ANUNC_LICIT]
    l.use_parser :LIST_PARSER, :ANUNC_LICIT
  end

  scr.levels << Webscrutinizer::Level.new do |l|
    l.uri = SEEDS[:ADJUD_PROV]
    l.use_parser :LIST_PARSER, :ADJUD_PROV
  end

  scr.levels << Webscrutinizer::Level.new do |l|
    l.uri = SEEDS[:ADJUD_DEF]
    l.use_parser :LIST_PARSER, :ADJUD_DEF
  end

  scr.levels << Webscrutinizer::Level.new do |l|
    l.uri = SEEDS[:FORMALITZACIONS]
    l.use_parser :LIST_PARSER, :FORMALITZACIONS
  end

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
        :EXP => exp.strip.upcase,
        :TIPUS => itm1.text.strip,
        :LNK => lnk,
        :DESCRIPCIO => descr,
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
        {k.to_sym => v}
      else
        {}
      end
    end.inject({}) {|ac,hsh| ac.merge! hsh if hsh}
    # adding links to documents
    docs = []
    @page.search("li a").each_with_index do |item, i|
      k=item.text.strip
      v="http://w10.bcn.cat/APPS/gefconcursosWeb/"+item['href']
      docs << {:NAM => k, :LNK => v}
    end
    details[:DOCS]=docs unless docs.empty?
    # return
    {
      :CONTENT => details
    }
  end

end

# ... i comença la cosa
ws.scrutinize
#ws.report
p ws.statistics

#guarda els expedients
File.open(EXP_FILE,'w') do |f|
  YAML.dump(ws.receivers,f)
end

# guarda l'objecte per a persistir
#File.open(LOOKUP_FILE,'w') do |f|
#  YAML.dump(lookup,f)
#end

log1.close