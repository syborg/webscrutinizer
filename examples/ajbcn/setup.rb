# setup
# Marcel Massana 11-Sep-2011
#
# particularitzacions del Webscrutinizer pel perfil del contractant de
# l'Ajuntament de Barcelona
# (http://w10.bcn.cat/APPS/gefconcursosWeb/concursosList.do?idioma=ca)

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
    _nam = "ajbcn"

    # DEMO'S OWN CONFIGURACTION
    c.online = false   # if true -> application accesses internet
    # if false -> application uses Fakeweb to access pages

    # saving pages
    c.dump = false    # if true -> accessed pages will be saved
    # if false -> accessed pages won't be saved
    # dir where dumped files will be stored
    c.dump_dir = File.expand_path("tmp/web_dumps","~")
    # extension of dumped files. If "gz" is used they will be compressed and
    # cannot be used by Fakeweb because it needs plain files
    c.dump_ext = ".html"

    # logging
    c.log = true      # if true -> log info will be saved
    # if false -> log info won't be saved
    c.log_file = File.join(_dir,"tmp", _nam + ".log")
    c.log_level = Logger::DEBUG
    
    # parsed data
    c.saveparsed = true
    c.saveparsed_file = File.join(_dir,"tmp", _nam + "_exp.yml")

    # simple map
    c.lookup = true
    c.lookup_file = File.join(_dir,"tmp", _nam + "_lookup.yml")

    # Pagines inicials per scrutinitzar
    c.seeds = {
      # Informacio previa de futures licitacions
      :ANUNCIS_PREVIS => "http://w10.bcn.cat/APPS/gefconcursosWeb/anuncisList.do?idioma=ca",
      # Licitacions en curs pendents de que venci la data de presentacio
      :ANUNC_LICIT => "http://w10.bcn.cat/APPS/gefconcursosWeb/concursosList.do?idioma=ca",
      # Adjudicacions Provisionals
      :ADJUD_PROV => "http://w10.bcn.cat/APPS/gefconcursosWeb/adjudicacionsProvList.do?idioma=ca",
      # Adjudicacions Definitives
      :ADJUD_DEF => "http://w10.bcn.cat/APPS/gefconcursosWeb/adjudicacionsList.do?idioma=ca",
      # Formalitzacions/signatures de Contracte
      :FORMALITZACIONS => "http://w10.bcn.cat/APPS/gefconcursosWeb/formalitzacionsList.do?idioma=ca"
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