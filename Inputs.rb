require '/Users/andrei/Workspace/Environment/Programming/Library/Ruby/require_many'

# allow quick class reference
require 'searchable_namespaces'

# -------------------------------------
# class structure

class CodeInput
  class SurfaceLogic
    class TreeNode; end
    class Positive     < TreeNode; end
    class Negative     < TreeNode; end
    class Union        < TreeNode; end
    class Intersection < TreeNode; end
  end
  class InputObject; end
  class Surface  < InputObject; end
  class Cell     < InputObject; end
  class Material < InputObject; end
  class Lattice  < InputObject; end
  class Universe < InputObject; end
end


class Mcnp
  class Input < CodeInput
    class Surface  < CodeInput::Surface  ; end
    class Cell     < CodeInput::Cell     ; end
    class Material < CodeInput::Material ; end
    class Lattice  < CodeInput::Lattice  ; end
    class Universe < CodeInput::Universe ; end
  end
end


class Serpent
  class Input < CodeInput
    class Nest     < InputObject; end
    class Surface  < CodeInput::Surface  ; end
    class Cell     < CodeInput::Cell     ; end
    class Material < CodeInput::Material ; end
    class Lattice  < CodeInput::Lattice  ; end
    class Universe < CodeInput::Universe ; end
    class WordScanner; end
    class McnpMaker; end
  end
end


# -----------------------------------
# accessors

class CodeInput
  attr_accessor :surfaces, :materials, :cells, :lattices, :universes, :tallies, :parameters, :comments
end

    class Mcnp::Input
      attr_accessor :tallies
    end

    class Serpent::Input
      attr_accessor :nests
    end

class CodeInput::SurfaceLogic::TreeNode
  attr_accessor :nodes, :surface
end

class CodeInput::InputObject
  attr_accessor :id, :comments
end

class CodeInput::Universe
  attr_accessor :cells
end

class CodeInput::Surface
  attr_accessor :type, :parameters
end

class CodeInput::Material
  attr_accessor :density, :composition
end

  class Mcnp::Input::Material
    attr_accessor :name, :temperature
  end

class CodeInput::Cell
  attr_accessor :universe, :surfaces, :material, :fill
end

    class Mcnp::Input::Cell
      attr_accessor :importance, :coordinates_transformation, :temperature, :density
    end

class CodeInput::Lattice
  attr_accessor :elements, :dimensions, :type
end

    class Serpent::Input::Lattice
      attr_accessor :center, :pitch
    end

class Serpent::Input::Nest
  attr_accessor :layers, :surface_type
end


class Serpent::Input::WordScanner
  attr_reader :words
end

class Serpent::Input::McnpMaker
  attr_reader :mcnp_input
end

# -----------------------------------
# methods

class CodeInput
  def initialize
    @nests, @surfaces, @materials, @universes, @lattices, @cells, @parameters, @comments = Array.new(10) {{}}
  end
end

class CodeInput::InputObject
  def initialize input, id
    @input, @id = input, id
    @comments = []
    yield self if block_given?
  end
  # parse, to_s, validate
end

class CodeInput::Cell
  def initialize *args
    @surfaces = SurfaceLogic::Intersection.new
    super *args
  end
end

    class Mcnp::Input::Cell
      def initialize *args
        @importance = 1
        @fill = nil
        super *args
      end
    end

class CodeInput::Universe
  def initialize *args
    @cells = []
    super *args
  end
end

class CodeInput::Lattice
  def initialize *args
    @elements = []
    super *args
  end
end



# load classes
require_many %w[
  SurfaceLogic
  McnpInput
  McnpInputPrinter
  SerpentInput
  SerpentInputParserWordScanner
  SerpentInputMcnpMaker
]





# -------------------------------------
# tests

#Kernel.system 'cd /Users/andrei/Workspace/Delete/Work/Inputs/'
#Kernel.system "erb  pad_test.serpent.erb  >  pad_test.serpent"

# path = '/Users/andrei/Workspace/Delete/Work/Inputs/serpent2mcnp/'
# # Kernel.system "erb #{path}pad_test.serpent.erb > #{path}pad_test.serpent"
# File.new("#{path}pad_test.mcnp",'w+').write Serpent::Input.new("#{path}pad_test.serpent").to_mcnp.to_s
# File.new("#{path}hex_test.mcnp",'w+').write Serpent::Input.new("#{path}hex_test.serpent").to_mcnp.to_s
# File.new("#{path}lat_test.mcnp",'w+').write Serpent::Input.new("#{path}lat_test.serpent").to_mcnp.to_s
# File.new("#{path}pad_test.mcnp",'w+').write Serpent::Input.new("#{path}pad_test.serpent").to_mcnp.to_s



# si = Serpent::Input.new("#{path}pad_test.serpent")
#p si.surfaces.count
# mi = si.to_mcnp
# #p mi.surfaces.count
# s = mi.to_s
# File.new("#{path}pad_test.mcnp",'w+').write s



# i = Serpent::Input::SurfaceLogic::Intersection.new()
# # # p i.type_to_class
# i.add_node :negative
# i.add_node :positive
# i.add_node :negative#: Object.new()
# i.add_node :union do |n|
#   n.add_node :positive
#   n.add_node :negative
#   n.add_node :positive
# end
# 
# i.interate_simple_nodes do |node|
#   p node.surface
# end
# 
# 
# puts i.print, i.invert.print
# 
# exit
