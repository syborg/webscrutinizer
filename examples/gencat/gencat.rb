# Scrutinizing Expedients de la Generalitat de Catalunya
# Marcel Massana 09-Oct-2011

lib = File.expand_path('../../lib')
$: << lib unless $:.include? lib

require './setup'

require 'yaml'
# aixo permet utilitzar .ya2yaml en comptes de .to_yaml, evitant les sortides
# binaries d'aquest posant-ho tot en ascii (escapant els utf8)
require 'ya2yaml'

#$KCODE = 'UTF8'

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
  @setup.seeds.to_hash.each do |name,uri|
    scr.seed uri, :LIST_PARSER, name
  end

  # PARSERS
  # parser de llistes de concursos
  scr.define_parser :LIST_PARSER do
    exps = compose(@page.search("dt a"),@page.search("dd")) do |itm1,itm2|
      lnk = "https://contractaciopublica.gencat.cat/ecofin_pscp/AppJava/" + itm1['href']
      lvl = Webscrutinizer::Level.new do |l|
        l.uri = lnk
        l.use_parser :DETAIL_PARSER, :_SELF
      end
      {
        "desc" => clear_string(itm1.text),
        "lnk" => lnk,
        "TIP_ANUNCI" => itm2.text[/Esmen/] ? :ESMENA : :PUBLICACIO,
        "date_publ" => itm2.text[/[\d\/]+ [\d:]*/m],
        :_SUBLEVELS => [lvl]
      }
    end
    ret = { :CONTENT => exps }
    # mirem si hi ha siblings
    if lnk = @page.link_with(:text => "Següent") # nil si no n'hi ha
      lsibl = Webscrutinizer::Level.new do |l|
        l.uri = "https://contractaciopublica.gencat.cat/ecofin_pscp/AppJava/"+lnk.href
        l.use_parser :LIST_PARSER, :_SELF
      end
      ret[:SIBLINGS]=[lsibl]
    end
    ret
  end

  # @todo parsejar tambe el link a l'anunci (arxiu .zip que conté pdf i xml) que queda a la dreta.
  # En alguns detalls no hi es.
  # @todo el camp :DESCRIPCIO s'ha de diferenciar del que s'ha trobat al :LIST_PARSER
  # perque pot ser un text bastant mes llarg explicant en mes profunditat l'anunci,
  # des de les tasques que correspon el projecte a una esmena. Podriem anomenar-lo :DESCRIPCIO2
  # (exemple https://contractaciopublica.gencat.cat/ecofin_pscp/AppJava/notice.pscp?reqCode=viewCtn&idDoc=3443442&)
  # @todo la :DATA_OBERTURA_PL no s'aplica correctament
  # per exemple https://contractaciopublica.gencat.cat/ecofin_pscp/AppJava/notice.pscp?reqCode=viewCn&advancedSearch=false&idDoc=3576092&
  # @todo la imbricacio de key-values en els criteris (i potser altres) no esta ajustada
  # veure https://contractaciopublica.gencat.cat/ecofin_pscp/AppJava/notice.pscp?reqCode=viewCn&advancedSearch=false&idDoc=3571838&
  # @todo valorar la possibilitat d'aprofitar de que en el detall hi ha links de mes detalls
  # a les esmenes o a l'anunci inicial ....
  scr.define_parser :DETAIL_PARSER do
    area = @page.search("#contingut")
    details = {}
    area.search("dt").each do |dt|
      nodes = dt.search("./following-sibling::*")
      init_index=nodes.index(dt.at("./following-sibling::*"))
      end_index=nodes.index(dt.at("./following-sibling::dt[1]"))
      nodes = nodes.slice(init_index, end_index - init_index) if end_index
      text = nodes.map {|n| clear_string(n.search("./text() | ./span/text()").to_s, :encoding => 'ASCII')}.join(" / ")
      details[@lookup[clear_string(dt.text)]]=text
    end
    # links a documents
    docs = area.search(".destacat a").map do |item|
      nam=item.text.strip
      lnk="https://contractaciopublica.gencat.cat"+item['href']
      {"nam" => nam, "lnk" => lnk}
    end
    # un ultim document es l'anunci i la firma digital
    if anunc=area.at(".document-detall-oferta a")
      docs << {:NAM => "Anunci PDF i firma XML",
        :LNK => "https://contractaciopublica.gencat.cat"+anunc['href']}
    end
    details["docs"] = docs unless docs.empty?
    {
      :CONTENT => details
    }
  end

end
#######################

###########################
# MAIN
###########################
ws.scrutinize #:maxpages => 50
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
    #f.write ws.receivers.ya2yaml(:syck_compatible => true)
  end
end

#####################
# SimpleMap Teardown
#
if @setup.lookup
  File.open(@setup.lookup_file,'w') do |f|
    YAML.dump(lookup,f)
    #f.write lookup.ya2yaml(:syck_compatible => true)
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
