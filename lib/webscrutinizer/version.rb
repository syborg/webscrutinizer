# it's only a version number

module Webscrutinizer

  module Version

    MAJOR = 0
    MINOR = 0
    PATCH = 0
    BUILD = 'pre3'  # use nil if not used
	
    STRING = [MAJOR, MINOR, PATCH, BUILD].compact.join(".")

  end

end
