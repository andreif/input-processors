




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
  
end





# 
# # default settings to inherit
# class Mcnp::Input::Card
#   attr_accessor :id, :comments
#   def initialize input, id
#     @input, @id = input, id
#     @comments = []
#     yield self if block_given?
#   end
#   def parse words; end
#   def to_s; end
#   def validate; end
# end




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



# class Mcnp::Input::Cell# < Mcnp::Input::Card
#   # attr_accessor :universe, :surfaces, :material, :fill, :importance
#   def initialize *args
#     @importance = 1
#     @fill = nil
#     super *args
#   end
#   
#   # def print_surf_set ss, group_dir = :inside
#   #   intersection = !(union = group_dir == :outside)
#   #   r = []
#   #   ss.each do |s|
#   #     dir,s = s.flatten
#   #     outside = !(inside = dir == :inside)
#   #     case s.class.to_s
#   #       when 'Array'
#   #         dir = {inside: :outside, outside: :inside}[dir] if union
#   #         r << '(%s)' % print_surf_set(s, dir)
#   #     else
#   #         r << '%s%s' % [(inside and intersection) || (outside and union) ? '-' : nil, s.id]
#   #     end
#   #   end
#   #   return r.join(union ? ' : ' : ' ')
#   # end
#   # 
#   # def print
#   #   r  = '%d ' % @id
#   #   if @material
#   #     r += '%s %s ' % [@material.id, @material.density]
#   #   else
#   #     r += '0 '
#   #   end
#   #   r += NX
#   #   r += " $ %s " % @comments.join('; ') unless @comments.empty?
#   #   r += NL + TB
#   #   r += self.print_surf_set( @surfaces)
#   #   r += CN + 'u=%s ' % @universe.id unless @universe.id == '0'
#   #   if @fill
#   #     r += CN if @universe.id == '0'
#   #     case @fill.class.to_s
#   #       when /Lattice/
#   #         r += @fill.print
#   #     else
#   #       r += 'fill=%s ' % @fill.id
#   #     end
#   #   end
#   #   # %s %s $ %s\n, , , s.parameters.join(' '), )#c.universe.id
#   #   r += NL
#   #   return r
#   # end
# end






# class Mcnp::Input::Universe# < Mcnp::Input::Card
#   # attr_accessor :cells
#   def initialize *args
#     @cells = []
#     super *args
#   end
# end


# class Mcnp::Input::Lattice# < Mcnp::Input::Card
#   # attr_accessor :elements, :dimensions, :type
#   def initialize *args
#     @elements = []
#     super *args
#   end
#   # def print
#   #   r = "lat=%d " % [  {sqare: 1, hexxc: 2, hexyc: 2}[@type] || raise  ]
#   #   r += "fill=-%1$d:%1$d -%2$d:%2$d -%3$d:%3$d " % @dimensions.collect{|d|d/2}
#   #   x,y,z = @dimensions
#   #   r += x.times.collect do |i|
#   #     CN + @elements[i*y,y].collect{|e|e.id}.join(' ')
#   #   end.join
#   #   return r
#   # end
# end







