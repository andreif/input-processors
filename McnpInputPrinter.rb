

class Mcnp::Input
  
  TB = ' '*5
  NL = "\n"
  NX = '' #' &'
  CN = NX + NL + TB
  
  def to_s *args
    importances = []
    cell_materials = {}
    # title
    r = @parameters['title'] + NL
    # comments
    r += 'c ' + @comments.values.join('; ') + NL
    # cells
    @cells.each_value do |c|
      r += c.to_s
      unless c.material.nil?
        cell_materials[ c.material.name ] ||= []
        cell_materials[ c.material.name ].push c.id
      end
      importances.push c.importance
    end
    # separator
    r << NL
    # surfaces
    @surfaces.each_value do |s|
      r += s.to_s
    end
    r << NL
    cell_materials.each_pair do |name,cells|
      r += "c %s = %s\n" % [name, cells.join(' ')]
    end
    # materials etc.
    unless args.include? :skip_materials
      @materials.each_value do |m|
        r += m.to_s
      end
    end
    # params
    r += 'imp:n ' + self.find_repeated(importances) + NL
    r += 'mode n' + NL
    unless args.include? :skip_materials
      @parameters.each_pair do |k,v|
        r += k + ' ' + v.join(' ') + NL unless k == 'title'
      end
    end
    r = textwrap(r,74,CN)
    return r
  end
  
  
  def find_repeated ary
    result = []
    ary.each do |curr|
      if not result.empty? and curr == result.last[:item]
        result.last[:repeated] += 1
      else
        result << {item: curr, repeated: 0}
      end
    end
    result = result.collect do |i|
      item,repeated = i.values
      if repeated.zero?
        item
      else
        [item, "%dr" % repeated]
      end
    end
    return result.flatten.join(' ')
  end
  
  
  def textwrap text, width, indent="\n"
    return text.split("\n").collect do |line|
      if line =~ /^c /i
        line
      else
        line.scan( /(.{1,#{width}})(\s+|$)/ ).collect{|a|a[0]}.join  indent
      end
    end.join("\n")
  end
end


class Mcnp::Input::Surface
  def to_s
    return "%-5d %-5s %s $ %s\n" % [@id, @type, @parameters.join(' '), @comments.join('; ')]
  end
end



class Mcnp::Input::Cell

  def print_surf_set node, brackets=false
    case node.type
      when :positive     then return node.surface.id.to_s
      when :negative     then return '-' + node.surface.id.to_s
      when :intersection
        r = node.nodes.collect {|n|self.print_surf_set(n,true)} .join(' ')
        return brackets ? '(%s)'% r : r
      when :union
        r = node.nodes.collect {|n|self.print_surf_set(n,true)}.join(' : ')
        return brackets && node.nodes.count > 1 ? '(%s)'% r : r
    end
  end
  
  def to_s
    r  = '%d ' % @id
    if @material
      r += '%s %s ' % [@material.id, @material.density]
    else
      r += '0 '
    end
    r += NX
    r += " $ %s " % @comments.join('; ') unless @comments.empty?
    r += NL + TB
    r += self.print_surf_set @surfaces
    r += CN + 'u=%s ' % @universe.id unless @universe.id == '0'
    r += ' tmp=%s ' % @temperature unless @temperature.nil?
    if @fill
      r += CN if @universe.id == '0'
      case @fill.class.to_s
        when /Lattice/
          r += @fill.to_s
      else
        r += 'fill=%s ' % @fill.id
      end
    end
    r += ' TRCL=(%s) ' % @coordinates_transformation.collect{|n|n.to_s}.join(' ') if @coordinates_transformation
    r += NL
    return r
  end
end


class Mcnp::Input::Material
  def to_s
    r = "m%d $ density %s g/ccm; %s\n" % [@id, @density, @comments.join('; ')]
    unless @composition.nil?
      @composition.each do |pair|
        iso, fr = pair
        r += TB + iso + ' ' + fr + NL
      end
    end
    return r
  end
end



class Mcnp::Input::Lattice
  def to_s
    r = "lat=%d " % [  {sqare: 1, hexxc: 2, hexyc: 2}[@type] || raise  ]
    r += "fill=-%1$d:%1$d -%2$d:%2$d -%3$d:%3$d " % @dimensions.collect{|d|d/2}
    x,y,z = @dimensions
    r += x.times.collect do |i|
      CN + @elements[i*y,y].collect{|e|e.id}.join(' ')
    end.join
    return r
  end
end



