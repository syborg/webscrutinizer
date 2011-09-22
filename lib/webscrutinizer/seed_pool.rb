# SeedPool
# Marcel Massana 22-Sep-2011
#
# Engloba la organitzacio de les URIs i parsers que s'han d'utilitzar

module Webscrutinizer

class SeedPool

    def initialize
    end

    #afegeix una URI per a scrutinitzar
    def add_uri(uri)
    end

    #elimina una URI per a scrutinitzar
    def rm_uri(uri)
    end

    #afegeix un parser per a scrutinitzar
    def add_parser(uri, parser)
    end

    # torna un array amb les URIs definides
    def uris
    end

    #torna un array amb els parsers
    def parsers(uri)
    end

end

end

