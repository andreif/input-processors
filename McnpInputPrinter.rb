

class Mcnp::Input
  
  TB = ' '*5
  NL = "\n"
  NX = '' #' &'
  CN = NX + NL + TB
  
  def to_s
    importances = []
    # title
    r = @parameters['title'] + NL
    # comments
    r += 'c ' + @comments.values.join('; ') + NL
    # cells
    @cells.each_value do |c|
      r += c.to_s
      importances.push c.importance
    end
    # separator
    r << NL
    # surfaces
    @surfaces.each_value do |s|
      r += s.to_s
    end
    r << NL
    # materials etc.
    @materials.each_value do |m|
      r += m.to_s
    end
    r += 'imp:n ' + importances.join(' ') + NL
    r += 'mode n' + NL
    @parameters.each_pair do |k,v|
      r += k + ' ' + v.join(' ') + NL unless k == 'title'
    end
    # r = r.split("\n").collect do |line|
    #   if line =~ /^(.{77,}\S+)\s*$/
    #     line.gsub! /^(.{1,77})(\s+|\Z)/, "\\1" + CN
    #     line.gsub! /\s+$/, ''
    #   end
    #   line
    # end .join("\n")
    r = textwrap(r,74,CN)
    #r = r.gsub(/\n(.{1,77})(\s+|\Z)/, "\n\\1" + CN)
    #r = r.gsub(/(.{1,77})( +|$\n?)|(.{1,77})/, "\\1\\3 &\n     ")
    return r
  end
  
  def textwrap text, width, indent="\n"
    return text.split("\n").collect do |line|
      line.scan( /(.{1,#{width}})(\s+|$)/ ).collect{|a|a[0]}.join  indent
    end.join("\n")
  end
end


class Mcnp::Input::Surface
  def to_s
    return "%-5d %-5s %s $ %s\n" % [@id, @type, @parameters.join(' '), @comments.join('; ')]
  end
end



class Mcnp::Input::Cell# < Mcnp::Input::Card

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
    # intersection = !(union = group_dir == :outside)
    # r = []
    # ss.each do |s|
    #   dir,s = s.flatten
    #   outside = !(inside = dir == :inside)
    #   case s.class.to_s
    #     when 'Array'
    #       dir = {inside: :outside, outside: :inside}[dir] if union
    #       r << '(%s)' % print_surf_set(s, dir)
    #   else
    #       r << '%s%s' % [(inside and intersection) || (outside and union) ? '-' : nil, s.id]
    #   end
    # end
    # return r.join(union ? ' : ' : ' ')
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
    #@surfaces.each_simple_node do |node|
    #@surfaces.nodes.each do |node|
      r += self.print_surf_set @surfaces
    #end
    r += CN + 'u=%s ' % @universe.id unless @universe.id == '0'
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
    # %s %s $ %s\n, , , s.parameters.join(' '), )#c.universe.id
    r += NL
    return r
  end
end


class Mcnp::Input::Material
  def to_s
    r = "m%d $ density %s g/ccm; %s\n" % [@id, @density, @comments.join('; ')]
    @composition.each do |pair|
      iso, fr = pair
      r += TB + iso + ' ' + fr + NL
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



