


class Serpent::Input
  
  def initialize #path=nil
    @nests, @surfaces, @materials, @universes, @lattices, @cells, @parameters, @comments = Array.new(10) {{}}
    #@comments[:file] = path
    #if path_or_text =~ /\n/
    #Parser.new(path, self)
  end
  
  def get card
    type, id = card.keys.first, card.values.first
    case type
      when :c, :cell           then result = @cells[id] ||= Cell.new( self, id)
      when :s, :surf, :surface then result = @surfaces[id] ||= Surface.new( self, id)
      when :m, :mat, :material then result = @materials[id] ||= Material.new( self, id)
      when :u, :universe       then result = @universes[id] ||= Universe.new(self, id)
      when :nest               then result = @universes[id] = @nests[id] ||= Nest.new( self, id)
      when :lattice, :lat      then result = @universes[id] = @lattices[id] ||= Lattice.new( self, id)
    else
      raise "unknown card #{type}"
    end
    yield result if block_given?
    return result
  end

  
  def to_mcnp
    Input::McnpMaker.new(self).mcnp_input
  end
  
  
  def to_s
    self.to_s
  end
  
  def self.parse text
    return self.new.parse text
  end
  
  def parse text #file
    #raise "not found" unless File.exists? file
    #raise "cannot read" unless File.readable? file
    #raise "found # symbol" if file =~ /\#/
    #text = IO.read(file)
    
    words = WordScanner.new(text).parse
    
    cards = {header: [[]]}
    current_keyword = nil # must be defined outside block
    
    words.each do |word_info|
      fr,to = word_info.values
      word = text[fr..to]
      next if word.empty?
      if self.is_keyword? word
        leading_comments = []
        if current_keyword
          until cards[ current_keyword ].last.empty?
            break unless cards[ current_keyword ].last.last =~ /^([\#\%]|\/\*)/
            leading_comments << cards[ current_keyword ].last.pop
          end
        end
        current_keyword = word.downcase.to_sym
        cards[ current_keyword ] ||= []
        cards[ current_keyword ].push []#leading_comments
      else
        cards[ current_keyword || :header ].last.push word unless word =~ /^([\#\%]|\/\*)/
      end
    end
    
    
    {set: 2, mat: 4, surf: 3, cell: 4, nest:2, pin: 2, lat: 8}.each_pair do |key, min|
      next if not cards.has_key?(key) or cards[key].empty? # raise "no materials!"
      
      cards[key].each do |card_words|
        raise "bad definition of #{key} " if card_words.length < min
        id = card_words.shift
        case key
          when :set then @parameters[id] = card_words.length > 1  ? card_words : card_words.first
          when :pin then self.get(nest: id).parse( ['cyl'] + card_words )
        else
          self.get(key => id).parse  card_words
        end
      end
    end
    return self
  end
  
  
  def is_keyword? word
    %w[ cell det include lat mat pin nest particle disp pbed plot set surf therm trans mesh dep ene ].include? word.downcase
  end
  
# cell  cell definition
# det  detector definition
# include  read a new input file
# lat  lattice definition
# mat  material definition
# pin  pin definition
# nest  nest definition
# particle  particle definition
# disp  implicit HTGR particle fuel model
# pbed  explicit HTGR particle / pebble bed fuel model
# plot  geometry plotter
# set   misc. parameter definition
# surf  surface definition
# therm  thermal scattering data definition
# trans  universe transformation
# mesh  thermal flux and fission rate mesh plotter
# dep  irradiation history
  
  
end






class Serpent::Input::Nest
  def parse *words
    @surface_type = words.flatten!.shift.downcase.to_sym
    raise "Surface type is not supported" unless n_params = {cyl:1,pz:1,hexxc:1,hexyc:1}[@surface_type]
    @layers = []
    until words.empty?
      case mat = words.shift
        when 'fill'
          @layers.push( universe: @input.get(u: words.shift), surface_parameters: words.shift(n_params))
      else
        @layers.push( material: @input.get(m: mat), surface_parameters: words.shift(n_params))
      end
    end
# p @id
# p @layers.each.collect { |l|
#   [l.values.first.class, l[:surface_parameters]]
# }
    # words.each_slice(2) do |pair|
    #   mat,rad = pair
    #   # fill 10  1.0
    #   @layers.push( material: @input.get(m: mat), outer_radius: rad)
    # end
    return self
  end
end


class Serpent::Input::Surface
  def parse words
    @type = words.shift.downcase
    @parameters = words
  end
end


class Serpent::Input::Material
  def parse words
    @thermal, @composition = [], {}
    @density = words.shift
    until words.empty?
      case key = words.shift
        when 'rgb'  then @color  = words.shift(3)
        when 'vol'  then @volume = words.shift
        when 'mass' then @mass   = words.shift
        when 'tmp'  then @temperature = words.shift
        when 'moder' then @thermal << words.shift(2)
        when /^[\#\%]/
      else
        @composition[key] = words.shift
      end
    end
  end
end



class Serpent::Input::Lattice

  def parse words
    @type = [:no, :square, :hexxc, :hexyc][words.shift.to_i]
    @center = words.shift(2)
    @dimensions = words.shift(2).collect {|d| d.to_i}
    @pitch = words.shift
    @elements = words.collect do |id|
      @input.get universe: id
    end
  end
end





class Serpent::Input::Cell
  
  def parse words
    @universe = @input.get universe: words.shift
    @universe.cells.push self # @universe.cells[@id] = self
    @material, @fill = nil, nil
    if (mat = words.shift).downcase == 'fill'
      @fill = @input.get universe: words.shift
    else
      @material = @input.get( material: mat)
    end
    words.each do |s|
      if s[0] == '-'
        @surfaces.add_node negative: @input.surfaces[ s[1..-1] ] # inside or below
      else
        @surfaces.add_node positive:  @input.surfaces[s] # outside or above
      end
    end
  end
end

