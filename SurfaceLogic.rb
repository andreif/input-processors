
class CodeInput::SurfaceLogic
  def self.node node
    case node
      when Symbol then node_type, surface = node, nil
      when Hash then node_type, surface = node.flatten
    else raise end
    conversion = {below: :negative, inside: :negative, above: :positive, outside: :positive}
    node_type = conversion[node_type] if conversion.has_key? node_type
    return self.type_to_class(node_type).new(surface)
  end
  
  def self.type_to_class type=nil
    self.const_get  (type || self.type).to_s.capitalize
  end
  
  def self.opposite_to type
    rules = {positive: :negative, intersection: :union}
    return rules[type] || rules.invert[type] || raise
  end
end



class CodeInput::SurfaceLogic::TreeNode
  
  def initialize surface=nil
    @nodes = []
    @surface = surface
    #@@id ||= 0; @surface ||= (@@id += 1) if self.is_type? :positive, :negative
    yield self if block_given?
  end
  
  
  def invert
    opposite = SurfaceLogic.type_to_class(self.opposite_type).new(@surface)
    @nodes.each do |node|
      opposite.add_node node.invert
    end
    yield opposite if block_given?
    return opposite
  end
  
  
  def add_node node
    case node
    when Symbol, Hash
      # case node
      #   when Symbol then node_type, surface = node, nil
      #   when Hash then node_type, surface = node.flatten
      # end
      # conversion = {below: :negative, inside: :negative, above: :positive, outside: :positive}
      # node_type = coversion[node_type] if conversion.has_key? node_type
      # @nodes << self.type_to_class(node_type).new(surface)
      @nodes << SurfaceLogic.node(node)
    else
      @nodes << node
    end
    yield @nodes.last if block_given?
    return @nodes.last
  end
  
  
  
  
  
  def type
    self.class.to_s.split('::').last.downcase.to_sym
  end
  
  
  def is_type? *types
    types.flatten.include? self.type
  end
  
  
  def opposite_type type=nil
    SurfaceLogic.opposite_to self.type
  end
  
  
  def each_simple_node &block
    block.call self unless @surface.nil?
    @nodes.each do |node|
      node.each_simple_node &block
    end
  end
  
  
  def surface_ids
    ids = []
    ids << @surface.id unless @surface.nil?
    @nodes.each do |node|
      ids += node.surface_ids
    end
    return ids.uniq
  end
  
  
  # def print
  #   case self.type
  #     when :positive     then return ' ' + @surface.to_s
  #     when :negative     then return '-' + @surface.to_s
  #     when :intersection then return '(' + (@nodes.collect {|n|n.print}.join('   ')) + ')'
  #     when :union        then return '(' + (@nodes.collect {|n|n.print}.join(' : ')) + ')'
  #   end
  # end
end