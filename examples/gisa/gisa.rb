# Scrutinizing Expedients de la Generalitat de Catalunya
# Marcel Massana 09-Oct-2011

require './setup'

require 'yaml'
# aixo permet utilitzar .ya2yaml en comptes de .to_yaml, evitant les sortides
# binaries d'aquest posant-ho tot en ascii (escapant els utf8)
require 'ya2yaml'
$KCODE = 'UTF8'

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

  # SEEDS
  scr.seed @setup.seeds.ANUNCIS_LICITACIO, :LIST_PARSER_1, :ANUNCIS_LICITACIO

  [ [:LIST_PARSER_2, :LICIT_PRESENTADES],
    [:LIST_PARSER_3, :LICIT_OB_TECN],
    [:LIST_PARSER_4, :LICIT_OB_ECON],
    [:LIST_PARSER_5, :LICIT_OBERTURA],
    [:LIST_PARSER_6, :LICIT_OB_LEMA] ].each do |par,rec|
    scr.seed @setup.seeds.LICITACIONS_PRESENTADES, par, rec
  end

  scr.seed @setup.seeds.ADJUDICACIONS, :LIST_PARSER_8, :ADJUDIC_PROVS
  scr.seed @setup.seeds.ADJUDICACIONS, :LIST_PARSER_9, :ADJUDIC_DEFS

  scr.seed @setup.seeds.FORMALITZACIONS, :LIST_PARSER_10, :FORMALITZACIONS

  #   aquest es un resum dels darrers dels altres ... no cal
  #    scr.levels << Webscrutinizer::Level.new do |l|
  #      l.uri = GISA_PAGES[:ANUNCIS_PREVIS]
  #      l.use_parser :LIST_PARSER_7, :ANUNCIS_PREVIS
  #    end

  # PARSERS
  # codi comu per a parsejar llistats d'anuncis (concursos, adjudicacions, ...)
  # admet un hash amb alguns arguments:
  # :xpath es un string que indica el XPATH de la zona on parsejar
  # :labels es un array amb les etiquetes que es volen utilitzar pels camps
  # :sparser es un symbol que indica quin parser s'ha de fer anar per siblings
  # :dparser es un symbol que indica quin parser s'ha de fer anar per detalls d'elements
  scr.define_parser :LIST_BASIC_PARSER do |*args|
    # si no rebem arguments esperats posem per defecte valors correctes
    xpath = "/html/body/table[3]/tr/td[2]/table/tr[2]/td[3]/table[2]/tr"
    lbls = [:EXP, :REGULACIO, :DESCRIPCIO, :PRESSUP_BASE, :DATA1, :DATA2]
    sparser = :LIST_BASIC_PARSER
    dparser = nil
    if args && arg=args[0]
      xpath = arg[:xpath] if arg.has_key? :xpath
      lbls = arg[:labels] if arg.has_key? :labels
      sparser = arg[:sparser] if arg.has_key? :sparser
      dparser = arg[:dparser] if arg.has_key? :dparser
    end
    # inicialitzem acumuladors
    exps = []
    sblngs={}
    @page.search(xpath).each do |row|
      lnk = row.at("a") # Nomes ens interessen les files amb links, les altres son d'adorno
      if lnk["href"].match /ID/ # totes les que tenen ID al URL son concursos
        lnk="http://www.gisa.cat"+lnk['href']
        dades = even_values(row.search("td").to_a)
        nota = row.search("span[@class]").remove  # Si hi ha un texte vermell es una nota que es treu i es guarda a part
        nota = clear_string(nota.first.text) if nota.size > 0
        hash1=compose(lbls.dup,dades) do |lbl,dada|
          # nomes em quedo amb els elements que tinguin alguna informacio (un string no nul)
          if dada
            val = clear_string(dada.content)
            {lbl=>val} unless val.empty?
          end
        end.compact # elimina elements nil
        hash2={:LNK => lnk}
        hash2.merge!(:NOTA => nota) unless nota.empty?
        hash=hash1.inject(hash2) do |ac,el|
          ac.merge el if el
        end
        # Darreres correccions:
        # A :EXP pot haber-hi informacio de :TIPUS tambe.
        # Ho intentem separar amb regexps
        if hash[:EXP] =~ /^([A-Z\+]+)[\.\s]+/
          hash[:TIPUS], hash[:EXP]=hash[:EXP].match(/^([A-Z\+]+)[\.\s]+(.+)$/).captures
        end
        # finalment hi afegim el nivell de detalls
        if dparser
          lvl = Webscrutinizer::Level.new do |l|
            l.uri = lnk
            l.use_parser :DETAIL_BASIC_PARSER, :_SELF # la part de dalt sempre igual
            l.use_parser dparser, :_SELF
          end
          hash[:_SUBLEVELS]=[lvl]
        end
        exps << hash # ho afegim a la llista
      else  # la pagina següent seria el primer enllaç despres del <b>n</b>
        if row.search("td/b").first
          ln=row.search("td/b").first.next_element
          if ln && ln.matches?("a")
            lvl = Webscrutinizer::Level.new do |l|
              l.uri = "http://www.gisa.cat#{ln["href"]}"
              l.use_parser sparser, :_SELF
            end
            sblngs = { :SIBLINGS => [lvl] }
          end
        end
      end if lnk
    end
    sblngs.merge!({ :CONTENT => exps })
  end

  # parser basic i comu de detalls dels anuncis (mira la part de dalt que es comu a tots)
  scr.define_parser :DETAIL_BASIC_PARSER do
    details = {}
    @page.search("/html/body/table[3]/tr/td[2]/table/tr[2]/td[3]/table[2]/tr/td[2]/table/tr[7]/td[3]/table//tr").each do |row|
      v=row.at("td[2]")
      if v
        k = @lookup[clear_string(row.at("td[1]").text)]
        details[k]=clear_string(v.text)
        #print_debug "Que passa amb els accents?", row.at("td[1]").text, v.text, clear_string(v.text), v.text.scan(/./mu) # DEBUG
      end
    end
    # documents addicionals
    docs = @page.search("/html/body/table[3]/tr/td[2]/table/tr[2]/td[3]/table[2]/tr/td//a").map do |doc|
      { :NAM => clear_string(doc.text),
        :LNK => "http://www.gisa.cat"+clear_uri(doc['href']),
        :DESC => clear_string(doc.parent.text) }
    end
    details[:DOCS_ANUNCIS]=docs if docs.any?
    {
      :CONTENT => details
    }
  end

  # parser de detalls dels anuncis
  scr.define_parser :DETAIL_ANUNCI_PARSER do
    details = {}
    # en alguns casos es table[4] i en alguns table[5]
    docs=@page.search("/html/body/table[3]/tr/td[2]/table/tr[2]/td[3]/table[position()=5 or position()=4]//a[@class]").map do |lnk|
      if lnk['href'] =~ /Doc\('.*'\)/ # ates lo anterior ... poden haber enllaços no valids
        docname = clear_string(lnk.text)
        doclnk = "http://www.gisa.cat"+clear_uri(lnk['href'])  # agafem l'argument de la funcio javascript
        {:NAM=>docname, :LNK=>doclnk}
      end
    end
    details[:DOCS]=docs if docs.any?
    {
      :CONTENT => details
    }
  end

  # parser de llista d'ofertes, obertures, adjudciacions, etc
  scr.define_parser :TENDERERS_PARSER do
    details = {}
    tlist=nil # declarada aqui
    lbls = []
    area=@page.search("/html/body/table[3]/tr/td[2]/table/tr[2]/td[3]/table[position()=4 or position()=5]")
    area.search("tr").each do |row|
      # 'Ofertants', 'Acceptats', 'Adjudicació', 'Ofertes no Adjudicatàries', 'Exclosos'
      # 'Ofertes excloses per no assolir la qualitat tècnica mínima requerida segons el Plec de Bases'
      # 'Pendents de subsanar defectes de documentació administrativa'
      if itm = row.at("[@class='linkred3']")
        tlist = case clear_string(itm.text)
        when /Ofertants/ then :LEMPR_TENDER
        when /Acceptats/ then :LEMPR_ACCEPT
        when /Adjudicaci/ then :LEMPR_ADJUD
        when /no Adjud/ then :LEMPR_NOADJUD
        when /anorm/ then :LEMPR_TEMER
        when /Exclo/ then :LEMPR_EXCL
        when /subsanar/ then :LEMPR_SUBSANAR
        else :LEMPR_UNKNOWN
        end
        details[tlist]=[]
      else
        if tlist
          if lbls.empty?  # primer busquem la fila amb les etiquetes
            unless row.text.strip.empty?
              row.search(".//td[@class='txtgrey3'] | .//span[@class='txtgrey3']").each do |lbl|
                lbl=clear_string(lbl.text)
                lbls << case lbl
                when /Ter/ then :TRM  # Termini (mesos)
                when /Emp/ then :NAM  # Empresa
                when /Tip/ then :INT  # Tipus d'interès
                when /ort hom/ then :IMP_HOMO # Import homogeneïtzat (sense IVA)
                when /ort ofe/, /ort \(se/ then :IMP # Import oferta (sense IVA), Import (sense IVA)
                when /Sel/ then :SEL  # Seleccionats per presentar oferta
                when /Nac/ then :NAC  # Nacionalitat
                when /Dat/ then :DAD  # Data d'adjudicació
                else :DUMMY
                end
              end
            end
          elsif row.at("./td[@valign='top'] | ./td//a[not(@class)]")   # files amb dades
            tndr = compose(lbls.dup,row.search("./td[@valign='top'] | ./td//a[not(@class)]")) do |a,b|
              {a => b ? clear_string(b.text) : ""}
            end
            # transformem array de hashs a un sol hash i eliminem els dolents
            tndr = tndr.inject({}) do |ac,hsh|
              if hsh.has_value?("") or
                  hsh.has_value?(nil) or
                  hsh.has_key?(:DUMMY) or
                  hsh.has_key?(nil)
                ac
              else
                ac.merge! hsh
              end
            end
            # si hi ha un link l'afegim
            if lnk=row.at("a") then # si hi ha un link
              tndr[:LNK] = "http://www.gisa.cat"+clear_uri(lnk['href'])
            end
            details[tlist] << tndr unless tndr.empty?
          end
        end
      end
    end
    # puts details.size
    {
      :CONTENT => details
    }
  end

  # parser de formalitzacions
  scr.define_parser :FORMALITZ_PARSER do
    details = {}
    tlist=nil # declarada aqui
    lbls = []
    area=@page.search("/html/body/table[3]/tr/td[2]/table/tr[2]/td[3]/table[position()=4 or position()=5]")
    area.search("tr").each do |row|
      if lbls.empty?  # primer busquem la fila amb les etiquetes
        unless row.text.strip.empty?
          row.search(".//td[@class='txtgrey3']").each do |lbl|
            lbl=clear_string(lbl.text)
            lbls << case lbl
            when /Ter/ then :TRM  # Termini (mesos)
            when /Emp/ then :NAM  # Empresa
            when /ort \(se/ then :IMP # Import oferta (sense IVA)
            when /Dat/ then :DAS  # Data de signatura
            else :DUMMY
            end
          end
        end
      elsif row.at("./td[@valign='top']")
        tndr = compose(lbls.dup,row.search("./td[@valign='top']")) do |a,b|
          {a => b ? clear_string(b.text) : ""}
        end
        # transformem array de hashs a hash i corregim els dolents
        tndr = tndr.inject({}) do |ac,hsh|
          if hsh.has_value?("") or
              hsh.has_value?(nil) or
              hsh.has_key?(:DUMMY) or
              hsh.has_key?(nil)
            ac
          else
            ac.merge! hsh
          end
        end
        # si hi ha un link l'afegim
        if lnk=row.at("a") then
          tndr[:LNK] = "http://www.gisa.cat"+clear_uri(lnk['href'])
        end
        #pp row
        details[:LEMPR_FORMAL] = [tndr] unless tndr.empty?
      end
    end
    {
      :CONTENT => details
    }
  end


  # parser de llistes de concursos 1:
  # Licitacions Obertes (en curs)
  scr.define_on_parser :LIST_PARSER_1, :LIST_BASIC_PARSER,
    :xpath => "/html/body/table[3]/tr/td[2]/table/tr[2]/td[3]/table[2]/tr",
    :labels => [:EXP, :REGULACIO, :DESCRIPCIO, :PRESSUP_BASE, :DATA_ANUNC, :DATA_PRES],
    :sparser => :LIST_PARSER_1,
    :dparser => :DETAIL_ANUNCI_PARSER

  # parser de llistes de concursos 2
  # Licitacions presentades pendents d'obertura
  scr.define_on_parser :LIST_PARSER_2, :LIST_BASIC_PARSER,
    :xpath => "/html/body/table[3]/tr/td[2]/table/tr[2]/td[3]/table[2]/tr",
    :labels => [:EXP, :REGULACIO, :DESCRIPCIO, :PRESSUP_BASE, :DATA_OB_TEC, :DATA_OB_ECON ],
    :sparser => :LIST_PARSER_2,
    :dparser => :TENDERERS_PARSER

  # parser de llistes de concursos 3
  # Licitacions presentades amb obertura tecnica
  scr.define_on_parser :LIST_PARSER_3, :LIST_BASIC_PARSER,
    :xpath => "/html/body/table[3]/tr/td[2]/table/tr[2]/td[3]/table[3]/tr",
    :labels => [:EXP, :REGULACIO, :DESCRIPCIO, :PRESSUP_BASE, :DATA1, :DATA2],
    :sparser => :LIST_PARSER_3S,
    :dparser => :TENDERERS_PARSER
  # pels siblings
  scr.define_on_parser :LIST_PARSER_3S, :LIST_BASIC_PARSER,
    :xpath => "/html/body/table[3]/tr/td[2]/table/tr[2]/td[3]/table[2]/tr",
    :labels => [:EXP, :REGULACIO, :DESCRIPCIO, :PRESSUP_BASE, :DATA1, :DATA2],
    :sparser => :LIST_PARSER_3S,
    :dparser => :TENDERERS_PARSER

  # parser de llistes de concursos 4
  # Licitacions presentades amb Obertura economica
  scr.define_on_parser :LIST_PARSER_4, :LIST_BASIC_PARSER,
    :xpath => "/html/body/table[3]/tr/td[2]/table/tr[2]/td[3]/table[4]/tr",
    :labels => [:EXP, :REGULACIO, :DESCRIPCIO, :PRESSUP_BASE, :DATA_OB_ECON ],
    :sparser => :LIST_PARSER_4S,
    :dparser => :TENDERERS_PARSER
  # pels siblings
  scr.define_on_parser :LIST_PARSER_4S, :LIST_BASIC_PARSER,
    :xpath => "/html/body/table[3]/tr/td[2]/table/tr[2]/td[3]/table[2]/tr",
    :labels => [:EXP, :REGULACIO, :DESCRIPCIO, :PRESSUP_BASE, :DATA_OB_ECON ],
    :sparser => :LIST_PARSER_4S,
    :dparser => :TENDERERS_PARSER

  # parser de llistes de concursos 5
  # Licitacions presentades amb Obertura de lemes
  scr.define_on_parser :LIST_PARSER_5, :LIST_BASIC_PARSER,
    :xpath => "/html/body/table[3]/tr/td[2]/table/tr[2]/td[3]/table[5]/tr",
    :labels => [:EXP, :REGULACIO, :DESCRIPCIO, :PRESSUP_BASE, :DATA_OBERTURA ],
    :sparser => :LIST_PARSER_5S,
    :dparser => :TENDERERS_PARSER
  # pels siblings
  scr.define_on_parser :LIST_PARSER_5S, :LIST_BASIC_PARSER,
    :xpath => "/html/body/table[3]/tr/td[2]/table/tr[2]/td[3]/table[2]/tr",
    :labels => [:EXP, :REGULACIO, :DESCRIPCIO, :PRESSUP_BASE, :DATA_OBERTURA ],
    :sparser => :LIST_PARSER_5S,
    :dparser => :TENDERERS_PARSER

  # parser de llistes de concursos 6
  # Licitacions presentades amb Obertura de lemes
  scr.define_on_parser :LIST_PARSER_6, :LIST_BASIC_PARSER,
    :xpath => "/html/body/table[3]/tr/td[2]/table/tr[2]/td[3]/table[5]/tr",
    :labels => [:EXP, :REGULACIO, :DESCRIPCIO, :PRESSUP_BASE, :DATA_OB_LEMA ],
    :sparser => :LIST_PARSER_6S,
    :dparser => :TENDERERS_PARSER
  # pels siblings
  scr.define_on_parser :LIST_PARSER_6S, :LIST_BASIC_PARSER,
    :xpath => "/html/body/table[3]/tr/td[2]/table/tr[2]/td[3]/table[2]/tr",
    :labels => [:EXP, :REGULACIO, :DESCRIPCIO, :PRESSUP_BASE, :DATA_OB_LEMA ],
    :sparser => :LIST_PARSER_6S,
    :dparser => :TENDERERS_PARSER


  # parser de llistes de concursos 7
  # Anuncis de licitacio
  scr.define_on_parser :LIST_PARSER_7, :LIST_BASIC_PARSER,
    :xpath => "/html/body/table[3]/tr/td[2]/table/tr[2]/td[3]/table[2]/tr",
    :labels => [:EXP, :REGULACIO, :DESCRIPCIO, :PRESSUP_BASE, :DATA_ANUNCI ],
    :sparser => :LIST_PARSER_7,
    :dparser => :DETAIL_ANUNCI_PARSER

  # parser de llistes de concursos 8
  # Adjudicacions Provisionals
  scr.define_on_parser :LIST_PARSER_8, :LIST_BASIC_PARSER,
    :xpath => "/html/body/table[3]/tr/td[2]/table/tr[2]/td[3]/table[2]/tr",
    :labels => [:EXP, :REGULACIO, :ADJUDICATARI, :PRESSUP_BASE, :TERMINI, :DATA_ADJPROB ],
    :sparser => :LIST_PARSER_8,
    :dparser => :TENDERERS_PARSER

  # parser de llistes de concursos 9
  # Adjudicacions Definitives
  scr.define_on_parser :LIST_PARSER_9, :LIST_BASIC_PARSER,
    :xpath => "/html/body/table[3]/tr/td[2]/table/tr[2]/td[3]/table[3]/tr",
    :labels => [:EXP, :REGULACIO, :ADJUDICATARI, :PRESSUP_BASE, :TERMINI, :DATA_ADJDEF ],
    :sparser => :LIST_PARSER_9S,
    :dparser => :TENDERERS_PARSER
  # pels siblings
  scr.define_on_parser :LIST_PARSER_9S, :LIST_BASIC_PARSER,
    :xpath => "/html/body/table[3]/tr/td[2]/table/tr[2]/td[3]/table[2]/tr",
    :labels => [:EXP, :REGULACIO, :ADJUDICATARI, :PRESSUP_BASE, :TERMINI, :DATA_ADJDEF ],
    :sparser => :LIST_PARSER_9S,
    :dparser => :TENDERERS_PARSER

  # parser de llistes de concursos 10
  # Formalitzacions de Contractes
  scr.define_on_parser :LIST_PARSER_10, :LIST_BASIC_PARSER,
    :xpath => "/html/body/table[3]/tr/td[2]/table/tr[2]/td[3]/table[2]/tr",
    :labels => [:EXP, :DESCRIPCIO, :DATA_ADJDEF, :DATA_FORM ],
    :sparser => :LIST_PARSER_10,
    :dparser => :FORMALITZ_PARSER

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
