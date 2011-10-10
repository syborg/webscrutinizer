# helpers
# Marcel Massana 9-Oct-2011
#
# methods that helps parsing web pages (beyond than nokogiri does)

require 'rubygems'
require 'mme_tools/webparse'

module Webscrutinizer

  # This module should be included where helpers are needed to parse
  module Helpers

    include MMETools::Webparse

  end

end
