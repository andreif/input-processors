




class Mcnp::Input
  
  def get card
    type, id = card.keys.first, card.values.first
    case type
      when :c, :cell           then result = @cells[id] ||= Input::Cell.new( self, id)
      when :s, :surf, :surface then result = @surfaces[id] ||= Input::Surface.new( self, id)
      when :m, :mat, :material then result = @materials[id] ||= Input::Material.new( self, id)
      when :u, :universe       then result = @universes[id] ||= Input::Universe.new( self, id)
      when :lat, :lattice      then result = @universes[id] = @lattices[id] ||= Input::Lattice.new( self, id)
    else
      raise "unknown card #{type}"
    end
    yield result if block_given?
    return result
  end
  
  
  
  def add arg # can be -> (:material)  (material: 1..10)  (material: 1)  (material: [1, 100..999])
    # ------ defining arguments -----------------------
    case arg
      when Hash
        type = arg.keys.first
        try_id, range = nil, nil
        case v = arg.values.first
          when Array then try_id, range = v # -> input.add(material: [try, range])
          when Range then range = v # -> input.add(material: range)
          when Fixnum,String then try_id = v.to_i # -> input.add(material: id)
          when NilClass
        else
          raise arg.to_s
        end
      when Symbol # -> input.add(:material)
        type = arg
    else
      raise "bad argument"
    end
    range ||= { material: 1..99 }[type] || (1000..9999)
    try_id ||= range.to_a.first
    # ------------------------------------------------
    
    case type
      when :material then result = self.get material: self.find_free_id( @materials, range, try_id)
      when :cell     then result = self.get cell:     self.find_free_id( @cells,     range, try_id)
      when :surface  then result = self.get surface:  self.find_free_id( @surfaces,  range, try_id)
      when :universe then result = self.get universe: self.find_free_id( @universes, range, try_id)
      when :lattice  then result = self.get lattice:  self.find_free_id( @lattices,  range, try_id)
    else
      raise "bad type"
    end
    yield result if block_given?
    return result
  end
  
  
  
  
  def find_free_id hash, id_range=1..9999, try_id=1
    return try_id.to_s unless hash.has_key? try_id.to_s
    for id in id_range do
      return id.to_s unless hash.has_key? id.to_s
    end
    raise
  end
  
  # coors = [ [i j]*a + [k l]*b ; ... ]
  # coors = [ i,j,k,l ; ... ]; X = coors(:,1)*fa_pitch + coors(:,3)*pin_pitch
  def routes_to names, u = '0', path = []
    names = [names].flatten.collect{|n|n.to_s} if path.empty?
    routes = []
    @universes[u].cells.each do |c|
      c_path = path + [c.id]
      if c.material.nil?
        if c.fill.nil?
          # void
        elsif c.fill.class.to_s =~ /universe/i
          routes += self.routes_to( names, c.fill.id, c_path)
        else
          dx,dy = c.fill.dimensions
          c.fill.elements.collect {|el| el.id} .each_with_index do |id,i|
            lat = '[%3d %3d 0]' % [i%dx - dx/2, i/dx - dy/2]
            routes += self.routes_to( names, id, path + [c.id + lat] )
          end
        end
      elsif names.include? c.material.name #== name.to_s
        routes << c_path
      end
    end
    if path.empty? and not routes.nil?
      i = 0
      routes = routes.collect { |r| "     (%s) $ %d " % [r.reverse.join(' < '), i+=1] }
      coors = []
      routes.join.scan(/\[\s*(-?\d+)\s+(-?\d+)\s+\d+\s*\]/).each_slice(2) do |a|
        coors << a.flatten.join(' ')
      end
      matlab = "routes = [%s];" % coors.join(' ; ');
      return [routes, matlab]
    end
    return routes
  end
  
  
  
  
  def generate_cell_tree u='0', level=0
    children = []
    r = ''
    @universes[u].cells.each do |c|
      r << "c %sc%s:u%s = " % [' '*level*2, c.id, u]
      if c.material.nil?
        if c.fill.nil?
          r << "void"
        elsif c.fill.class.to_s =~ /universe/i
          r << 'u' + c.fill.id
          children << c.fill.id
        else
          r << "[%s]" % (
            c.fill.elements.collect {|el| el.id} .uniq.collect do |id|
              children << id
              id
            end.join(', ')
          )
        end
      else
        r << c.material.name
      end
      r << "\n"
    end
    children.each do |id|
      r << self.generate_cell_tree( id, level+1)
    end
    return r
  end
  
  
  
  def generate_universe_tree u='0', level=0
    r = "c %su%s = " % [' '*level*2, u]
    children = []
    @universes[u].cells.each do |c|
      r << "c%s:" % c.id
      if c.material.nil?
        if c.fill.nil?
          r << "void"
        elsif c.fill.class.to_s =~ /universe/i
          r << 'u' + c.fill.id
          children << c.fill.id
        else
          r << "[%s]" % (
            c.fill.elements.collect {|el| el.id} .uniq.collect do |id|
              children << id
              id
            end.join(', ')
          )
        end
      else
        r << c.material.name
      end
      r << ', '
    end
    r << "\n"
    children.each do |id|
      r << self.generate_universe_tree( id, level+1)
    end
    return r
  end
  
  
  def show_cell_materials
    cell_materials = {}
    @cells.each_value do |c|
      unless c.material.nil?
        cell_materials[ c.material.name ] ||= []
        cell_materials[ c.material.name ].push c.id
      end
    end
    cell_materials.each_pair do |name,cells|
      r += "c %s = %s\n" % [name, cells.join(' ')]
    end
  end
  
  
  def requested_ids u='0', result = {universes:[], cells:[], surfaces:[], materials:[]}
    result[:universes] << u
    @universes[u].cells.each do |c|
      result[:cells] << c.id
      result[:surfaces] += c.surfaces.surface_ids
      if c.material.nil?
        if c.fill.nil?
          # void
        elsif c.fill.class.to_s =~ /universe/i
          result = self.requested_ids( c.fill.id, result) unless result[:universes].include? c.fill.id
        else
          c.fill.elements.collect {|el| el.id} .uniq.each do |id|
            result = self.requested_ids( id, result) unless result[:universes].include? id
          end
        end
      else
        result[:materials] << c.material.id
      end
    end
    result.values.each { |v| v.uniq! } if u == '0'
    return result
  end
  
end








class Mcnp::Input::Surface
  def parse *words # can take: (type, params) ([type]+params)
    words.flatten!
    @type = words.shift
    @parameters = [words].flatten
    yield self if block_given?
    # self.validate
    return self
  end
end











