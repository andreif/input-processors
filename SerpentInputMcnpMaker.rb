# require '/Users/andrei/Workspace/Environment/Programming/Library/Ruby/require_many'
# require 'searchable_namespaces'
# require 'SerpentInput'
# require 'McnpInput'






class Serpent::Input::McnpMaker
  #attr_reader :mcnp_input
  
  def initialize input
    @serpent_input = input
    @mcnp_input = Mcnp::Input.new
    # conversion tables:
    @nests, @surfaces, @materials, @universes, @lattices, @cells = Array.new(10) {{}}
    
    self.serpent_to_mcnp
  end
  
  
  
  
  def serpent_to_mcnp
    self.convert_parameters
    %w[material surface lattice cell nest].each do |m|
      @serpent_input.send(m+'s').each_value do |v|
        self.send('convert_'+m, v)
      end
    end
    # self.remove_unused_objects
    self.remove_repeating_surfaces
    #self.join_similar_cells
  end
  
  
  def remove_unused_objects
  end
  
  
  def join_similar_cells
    r1 = self.select_similar_cells_if { |u,c| c.material.id unless c.material.nil? }
    r2 = self.select_similar_cells_if { |u,c| c.importance if c.importance.zero? }
    r3 = self.select_similar_cells_if { |u,c| c.fill.id unless c.fill.nil? }
    r1.merge(r2).merge(r3).each_pair do |from,to|
      @mcnp_input.cells[from].surfaces = SurfaceLogic::Union.new do |u|
        u.add_node  @mcnp_input.cells[from].surfaces
        to.each do |id|
          u.add_node  @mcnp_input.cells[id].surfaces
          @mcnp_input.cells.delete(id)
        end
      end
    end
    #p to_replace
  end
  
  
  def select_similar_cells_if &block
    result = {}
    @mcnp_input.universes.each_value do |u|
      next unless u.methods.include? :cells # i.e. lattice
      similar_cells = {}
      u.cells.each do |c|
        if marker = block.call(u,c)
          if similar_cells.has_key? marker
            # result[c.id] = similar_cells[ marker ]
            id = similar_cells[ marker ]
            result[id] ||= []
            result[id] << c.id
          else
            similar_cells[ marker ] = c.id
          end
        end
      end
    end
    return result
  end
  
  # def each_universe_cell &block
  #   @mcnp_input.universes.each_value do |u|
  #     next unless u.methods.include? :cells # i.e. lattice
  #     u.cells.each do |c|
  #       block.call(u,c)
  #     end
  #   end
  # end
  
  
  
  def remove_repeating_surfaces
    surface_levels = self.get_surface_levels( @universes['0'] )
    similar_surfaces = {}
    replace_surfaces = {}
    @mcnp_input.surfaces.each_value do |s|
      t,p,l = [s.type], s.parameters.collect{|p|p.to_f}, surface_levels[s.id]
      similar_surfaces[t+p]    ||= {}
      if similar_surfaces[t+p].has_key? l
        replace_surfaces[s.id] = similar_surfaces[t+p][l]
      else
        similar_surfaces[t+p][l] = s.id
      end
    end
    @mcnp_input.cells.each_value do |c|
      c.surfaces.each_simple_node do |node|
#p node.surface.class
        if replace_surfaces.has_key? node.surface.id
          node.surface = @mcnp_input.surfaces[ replace_surfaces[node.surface.id] ]
        end
      end
    end
    @mcnp_input.surfaces.delete_if {|id,surf| replace_surfaces.has_key? id }
  end
  
  def get_surface_levels universe, level=0, surface_levels={}
#p universe.id
    universe.cells.each do |cell|
      cell.surfaces.each_simple_node do |node|
        id = node.surface.id
        if surface_levels.has_key?( id ) and not surface_levels[id].equal?( level )
          raise "Surface %s is used on level %d and %d" % [id, surface_levels[id], level]
        else
          surface_levels[id] = level
        end
      end
      unless cell.fill.nil?
#p [cell.fill.class, cell.fill.id, @universes.keys]
        surface_levels = self.get_surface_levels(@universes[cell.fill.id], level+1, surface_levels)
      end
    end
    return surface_levels
  end
  
  
  def convert_lattice serpent_lattice
    id = serpent_lattice.id
    @mcnp_input.add(cell:900..999) do |c|
      c.universe = self.convert_universe(id)
      c.fill = @mcnp_input.add(:lattice) do |lat|
        lat.type = serpent_lattice.type
        lat.dimensions = serpent_lattice.dimensions + [0]
        # lat.elements = serpent_lattice.elements.collect { |u| self.convert_universe(u.id) }
        # reverse rows for mcnp format
        lat.elements = serpent_lattice.elements.each_slice(lat.dimensions.first).collect { |row|
          row.collect { |u| self.convert_universe(u.id) } .reverse
        } .reverse .flatten
      end
      
      case type = serpent_lattice.type
        when :square
          raise
          #c.surfaces.push
        when :hexxc,:hexyc
          x,y = serpent_lattice.center.collect{|str|str.to_f}
          c.coordinates_transformation = [x,-y,0] unless x.zero? and y.zero?
          # c.surfaces = self.surf_hex 400..999, type, [x,-y], serpent_lattice.pitch.to_f/2
          c.surfaces = self.surf_hex 400..999, type, [0,0], serpent_lattice.pitch.to_f/2
      else raise type end 
    end
  end
  
  
  def convert_universe id
    @universes[id] ||= @mcnp_input.get( universe: id)
    yield @universes[id] if block_given?
    return @universes[id]
  end
  
  
  def convert_cell serpent_cell
    unless @cells.has_key?(id = serpent_cell.id)
      @cells[id] = @mcnp_input.add(cell: id) do |c|
        
        c.universe = self.convert_universe(serpent_cell.universe.id) do |u|
          u.cells.push c
        end
        
        c.fill = self.convert_universe(serpent_cell.fill.id) if serpent_cell.fill
        
        if serpent_cell.material
          c.material = @materials[serpent_cell.material.id]
          c.comments.push serpent_cell.material.id
          c.importance = 0 if serpent_cell.material.id == 'outside'
        else
          c.material = nil
        end
        
        #c.surfaces = SurfaceLogic::Intersection.new
        serpent_cell.surfaces.nodes.each do |node|
          # c.surfaces.push(dir => @surfaces[s.id])
          # c.surfaces.add_node node.type => @surfaces[node.surface.id]
          case node.type
            when :negative then c.surfaces.add_node  @surfaces[node.surface.id]
            when :positive then c.surfaces.add_node  @surfaces[node.surface.id].invert
          else raise end
        end
        
        c.comments.push "cell #{id}" unless c.id == id
        c.comments += serpent_cell.comments
      end
    end
  end
  
  
  
  
  def convert_nest nest
    surf = nil
#p nest.id
    nest.layers.each do |layer|
      
      @mcnp_input.add(:cell) do |c|
        
        c.universe = @mcnp_input.get( universe: nest.id ) do |u|
          u.cells.push c
        end
        @universes[nest.id] ||= c.universe
        
        c.comments.push 'nest %d' % nest.id
        
        if mat = layer[:material]
          c.importance = 0 if mat.id == 'outside'
          c.material = @materials[mat.id]
          c.comments.push mat.id rescue c.comments.push mat
          
        elsif uni = layer[:universe]
          c.material = nil
          c.fill = @mcnp_input.get( universe: uni.id )
          @universes[uni.id] ||= c.fill
        end
        
        # previous surface
        c.surfaces.add_node  surf.invert if surf
        
        if not (params = layer[:surface_parameters]).empty?
          case type = nest.surface_type
            when :cyl
              surf = @mcnp_input.add(:surface).parse('cz',params) { |s| s.comments.push "pin #{nest.id}" }
              surf = c.surfaces.add_node( negative: surf )
            when :hexxc,:hexyc
              surf = self.surf_hex(nil,type,0,0,*params)
              surf = c.surfaces.add_node( surf )
            when :pz
              surf = @mcnp_input.add(:surface).parse('pz',*params) { |s| s.comments.push "nest #{nest.id}" }
              surf = c.surfaces.add_node( negative: surf )
          else raise "Surface type not supported" end
            
        elsif nest.layers.count < 2
          surf = @mcnp_input.add(:surface).parse('so','1e5') { |s| s.comments.push "nest #{nest.id}" }
          surf = c.surfaces.add_node( negative: surf )
        end
        
        #c.temperature = ?
      end
      
      # mat,rad = pair.values
      # if rad
      #   surf = @mcnp_input.add(:surface).parse('cz',rad) { |s| s.comments.push "pin #{pin.id}" }
      # elsif pin.layers.count < 2
      #   surf = @mcnp_input.add(:surface).parse('so','1e5') { |s| s.comments.push "pin #{pin.id}" }
      # else
      #   surf = nil
      # end

      # @mcnp_input.add(:cell) do |c|
      #   c.universe = @mcnp_input.get( universe: pin.id) do |u|
      #     u.cells.push c
      #   end
      #   
      #   c.importance = 0 if mat.id == 'outside'
      #   c.material = @materials[mat.id]
      #   
      #   # c.surfaces.push(inside: surf) if surf
      #   # c.surfaces.push(outside: prev_surf) if prev_surf
      #   
      #   c.surfaces.add_node( negative: surf) if surf
      #   c.surfaces.add_node( positive: prev_surf) if prev_surf
      #   
      #   c.comments.push 'pin %d' % pin.id
      #   c.comments.push mat.id rescue c.comments.push mat
      #   
      #   prev_surf = surf
      #   #c.temperature = ?
      # end
    end
#p @mcnp_input.universes.keys
  end
  
  
  
  def convert_parameters
    @mcnp_input.parameters['title'] = @serpent_input.parameters['title']
    npop,cycles,skip,keff0 = @serpent_input.parameters['pop']
    @mcnp_input.parameters['kcode'] = [npop, keff0||1, skip, cycles]
  end
  
  
  
  def convert_material serpent_material
    unless @materials.has_key? (id = serpent_material.id)
      @materials[ serpent_material.id ] = (id =~ /^(outside|void)$/) ? nil : @mcnp_input.add(:material) do |m|
        m.density = serpent_material.density
        m.composition = serpent_material.composition.dup
        m.comments.push serpent_material.id
        m.name = serpent_material.id
      end
    end
  end
  
  
  
  
  
  def surf_cyl try_id, x,y,r
    s = (x.to_f.zero? and y.to_f.zero?) ? ['cz',r] : ['c/z',x,y,r]
    return @mcnp_input.add(surface: try_id).parse(s)
  end
  
  
  def change_surf_direction dir
    return {inside: :outside, outside: :inside}[dir] || raise
  end
  
  def surf_plane try_id, dir, x,y,angle,d=0
    x = x.to_f; y = y.to_f; d = d.to_f
    a = angle.to_f % 360
    case a # angle zeros necessary to indicate float
      when 270.0 then s = ['px', x+d] 
      when  90.0 then s = ['px', x-d]; dir = change_surf_direction dir 
      when 180.0 then s = ['py', y-d]; dir = change_surf_direction dir 
      when   0.0 then s = ['py', y+d]
    else
      k = -Math.tan(a / 180.0 * Math::PI)
      d /= Math.cos(a / 180.0 * Math::PI).abs
      if a.abs.between?(90.0, 270.0)
        s = ['p',-k,-1,0, d-k*x-y] 
      else
        s = ['p', k, 1,0, d+k*x+y]
      end
    end
    return {
      dir => @mcnp_input.add(surface: try_id).parse(s) { |surf| surf.comments.push "angle #{angle}" }
    }
  end
  
  
  
  def norm_angles *angles
    #angles.flatten.collect { |a| (a.to_f <=> 0) * (a.to_f.abs % 360) } .sort
    angles.flatten.collect { |a| a.to_f % 360 }# .sort
  end

  
  def surf_hex *args
    id,type,x,y,halfpitch = args.flatten
    start = {hexxc:-90,hexyc:0}[type.to_sym]
    SurfaceLogic::Intersection.new do |i|
      3.times do |j| # it must be in 180-pairs because mcnp requires this
        i.add_node  self.surf_plane( id, :inside,  x,y, start+60*j, halfpitch)
        i.add_node  self.surf_plane( id, :inside,  x,y, start+60*j+180, halfpitch)
      end
    end
  end
  
  def convert_surface serpent_surface
    unless @surfaces.has_key?(id = serpent_surface.id)
      
      case (type = serpent_surface.type).to_sym
        
        when :hexxc,:hexyc
          
          #x,y,halfpitch = serpent_surface.parameters
          #start = {hexxc:-90,hexyc:0}[type.to_sym]
          #6.times { |i| s.push self.surf_plane( id, :inside,  x,y, start+60*i, halfpitch) }
          s = self.surf_hex( id, type, serpent_surface.parameters)
          
        when :pad
          
          x,y,r1,r2,t1,t2 = serpent_surface.parameters
          diff = (t2.to_f - t1.to_f).abs % 360
          s = SurfaceLogic::Intersection.new do |i|
            i.add_node  outside: self.surf_cyl( id, x,y,r1)
            i.add_node  inside:  self.surf_cyl( id, x,y,r2) 
            if diff > 180.0
              i.add_node :union do |u|
                u.add_node  self.surf_plane( id, :outside,  x,y,t1)
                u.add_node  self.surf_plane( id, :inside, x,y,t2)
              end
            elsif diff == 180.0
              i.add_node  self.surf_plane( id, :outside, x,y,t1)
            else # intersection
              i.add_node  self.surf_plane( id, :outside, x,y,t1)
              i.add_node  self.surf_plane( id, :inside,  x,y,t2)
            end
          end
          
        when :cyl
          s = SurfaceLogic::Negative.new self.surf_cyl( id, *serpent_surface.parameters)
          
        when :sph
          x,y,z,r = serpent_surface.parameters
          params = (x.to_f.zero? && y.to_f.zero? && z.to_f.zero?) ? ['so',r] : ['s',x,y,z,r]
          s = SurfaceLogic::Negative.new @mcnp_input.add( surface: id).parse(params)
          
        when :pz,:px,:py
          s = SurfaceLogic::Negative.new @mcnp_input.add( surface: id).parse(type, serpent_surface.parameters)
          
        else raise "surface type #{type} is not supported" 
      end
      cm = 'surf %s %s' % [id, serpent_surface.type]
      #s.comments.push cm rescue s.each { |ss| ss.values.first.comments.push cm } rescue
      @surfaces[id] = s
    end
  end
end



