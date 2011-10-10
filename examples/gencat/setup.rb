# setup
# Marcel Massana 9-10-2011
#
# particularitzacions del Webscrutinizer pel perfil del contractant de
# la Generalitat de Catalunya
# (https://contractaciopublica.gencat.cat/)

require 'rubygems'
require 'mme_tools/config'
require 'logger'

# per guardar i recuperar totes les configuracions es pot modificar l'arxiu
# 'config.yml'. Si s'esborra es regenera.
# la configuracio queda en l'objecte @setup de tipus MMETools::Config que es pot
# usar des d'on es 'requereixi' aquest arxiu.
if File.exist?("config.yml")
  @setup = MMETools::Config.load("config.yml")
else
  @setup = MMETools::Config.new do |c|

    _dir = File.expand_path(File.dirname(__FILE__))
    _nam = "gencat"

    # DEMO'S OWN CONFIGURACTION
    c.online = true   # if true -> application accesses internet
    # if false -> application uses Fakeweb to access pages

    # saving pages
    c.pdump = false    # if true -> accessed pages will be saved
    # if false -> accessed pages won't be saved
    # dir where dumped files will be stored
    #c.pdump_dir = File.expand_path("tmp/web_dumps","~")
    c.pdump_dir = "~/tmp/web_dumps"
    # extension of dumped files. If "gz" is used they will be compressed and
    # cannot be used by Fakeweb because it needs plain files
    c.pdump_ext = ".html"

    # saving data
    c.ddump = true    # if true -> parsed data will be saved
    # if true -> parsed data won't be saved
    # directory where parsed data will be saved
    c.ddump_dir = "tmp/data_dumps"
    # format of saved files
    c.ddump_format = :json


    # logging
    c.log = true      # if true -> log info will be saved
    # if false -> log info won't be saved
    #c.log_file = File.join(_dir,"tmp", _nam + ".log")
    c.log_file = File.join("tmp", _nam + ".log")
    c.log_level = Logger::DEBUG
    
    # parsed data
    c.saveparsed = true
    #c.saveparsed_file = File.join(_dir,"tmp", _nam + "_exp.yml")
    c.saveparsed_file = File.join("tmp", _nam + "_exp.yml")

    # simple map
    c.lookup = true
    #c.lookup_file = File.join(_dir,"tmp", _nam + "_lookup.yml")
    c.lookup_file = File.join("tmp", _nam + "_lookup.yml")

    # Threaded Agent
    c.num_threads = 8
    
    # Pagines inicials per scrutinitzar
    c.seeds = {
      # Futures licitacions que ja estan una mica passades ... Em sembla que ja no esta mantinguda aquesta seccio
      :ALERTES_FUTURES=> "https://contractaciopublica.gencat.cat/ecofin_pscp/AppJava/search.pscp?reqCode=searchCtn&set-locale=ca_ES",
      # Anuncis Previs: Futures licitacions que sembla que estan una mica mes actualitzades, tot i que algunes son molt velles
      :ANUNC_PREV => "https://contractaciopublica.gencat.cat/ecofin_pscp/AppJava/search.pscp?reqCode=searchPin&advancedSearch=false",
      # Anuncis de Licitacions en curs: Licitacions que es poden concursar i encara no ha arribat la data de presentacio
      :ANUNC_LICIT => "https://contractaciopublica.gencat.cat/ecofin_pscp/AppJava/search.pscp?reqCode=searchCn&advancedSearch=false",
      # Adjudciacions provisionals
      :ADJUD_PROV =>"https://contractaciopublica.gencat.cat/ecofin_pscp/AppJava/search.pscp?reqCode=searchPcan&advancedSearch=false&lawType=1",
      # Adjudciacions definitives
      :ADJUD_DEFI =>"https://contractaciopublica.gencat.cat/ecofin_pscp/AppJava/search.pscp?reqCode=searchDcan&advancedSearch=false&lawType=1",
    }
  end
  @setup.dump "config.yml"
end

# Rest of required files and setups

# minim suport de utf-8 a Ruby 1.8, pero millor anar a Ruby 1.9
require 'jcode' if RUBY_VERSION < '1.9'
$KCODE = "u"
# includes generics
require 'yaml'
require 'fakeweb'
require 'uri_pathname'
# includes particulars
require '../../lib/webscrutinizer'  # use flag -I ../../lib to require the development .rb
# in other case, gem lib will be required
