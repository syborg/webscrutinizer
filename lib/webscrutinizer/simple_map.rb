# SimpleMap
# Classe senzilla per a crear hash que permeti classificar
# cadenes de texte facilment amb una sintaxi senzilleta.
# l?unica diferencia amb un hash es que se simplifica la
# interficie per a accedir-hi de forma mes convenient 'ala' DSL
#
# Comentaris:
# Inicialment la vaig definir com SimpleMap < Hash, pero vaig haver
# de refer-ho d'aquesta manera perque tots els metodes de Hash eren
# heretats i provocava efectes colaterlas. En especial, quan vaig
# voler serialitzar, el metode to_yaml nomes em serialitzava
# el Hash ppal, i no la resta d'instance variables. Per defecte,
# el metode to_yaml serialitza totes les instance variables.

# my_dir=File.dirname(__FILE__)
# require 'invert_hash'

class SimpleMap

  attr_reader :unmapped_keys
  attr_reader :data

  def initialize(&block)
    @data = {}
    @current_value = nil
    @unmapped_keys =[]
    yield self if block_given?
  end

  # Returns value associate to given +key+ if it exists, else, +key+ is returned
  # This permits use it as a translator for already stored keys, bypassing them
  # if SimpleMap doesn't know about its existence. For instance
  #   sm["Mister"]="Mr"
  #   puts sm["Mister"] # "Mr"
  #   puts sm["Mr."] # "Mr."
  def [](key)
    if @data.has_key?(key)
      @data[key]
    else
      @unmapped_keys << key unless @unmapped_keys.include? key
      key
    end
  end

  # assigns a +value+ to a +key+.
  def []=(key, value)
    @current_value = value
    @unmapped_keys.delete key
    @data[key]=value
  end

  # used in conjunction with _add_ method to add new key/value pairs when
  # defining a SimpleMap using DSL
  #   for "DEPT"
  #     add "Department", "Dept", "Dept.", "Dpt."
  #
  def for(value)
    @current_value = value
  end

  # used in conjunction with _for_ method to add new key/value pairs when
  # defining a SimpleMap using DSL
  #   for "DEPT"
  #     add "Department", "Dept", "Dept.", "Dpt."
  #
  def add(*keys)
    keys.each { |key| @data[key]=@current_value }
  end

  # returns the inverse of self, a Hash with swapped key/value pairs. For 
  # repeated values an array with all its keys are given.
  def reverse_data
    res = {}
    @data.each_pair do |k,v|
      res[v] ||=[]
      res[v] << k
    end
    res
  end
end
