#Meta and Builder
class Metabuilder
  attr_accessor :properties, :class_name, :actions

  def initialize
    self.properties = []
    self.actions = []
  end

  def set_target_class(class_name)
    self.class_name = class_name
  end

  def set_target_class_hierarchy(class_name, superclass_name=nil, dsl=false, &block)
    superclass = superclass_name || Object
    klass = Class.new(superclass) {}
    self.class_name = klass
    Object.const_set class_name, klass

    if block_given?
      if dsl
        ClassExecutionContext.new(klass).instance_eval &block
      else
        klass.class_eval &block
      end
    end

  end

  def add_properties(*sym)
    sym.each { |s| self.add_property s }
  end

  def add_property(sym)
    self.properties << "#{sym.to_s}=".to_sym
  end

  def validate(&block)
    @actions << Validation.new(block)
  end

  def conditional_method(name, condition, implementation)
    @actions << ConditionalMethod.new(name, condition, implementation)
  end

  def build
    Builder.new(self.class_name, self.properties, self.actions)
  end
end

class Builder
  attr_accessor :properties, :class_name, :actions

  def initialize(class_name, properties, actions)
    self.actions = actions
    self.class_name = class_name
    @properties = {}
    properties.each { |property| self.properties[property] = nil }
  end

  def set_attribute(sym, value)
    self.properties["#{sym}="] = value
  end

  def method_missing(name, *args, &block)
    raise BuildError unless self.properties.key? name
    self.properties[name] = args[0]
  end

  def build
    instance = self.class_name.new
    self.properties.each { |setter_name, value|
      instance.send setter_name, value
    }

    self.actions.each { |action|
      action.apply(instance)
    }

    instance
  end

end

#Actions
module Action
  attr_accessor :condition

  def valid(instance)
    instance.instance_eval &condition
  end

end

class ConditionalMethod
  include Action

  attr_accessor :name, :condition, :implementation

  def initialize(name, condition, implementation)
    self.name = name
    self.condition = condition
    self.implementation = implementation
  end

  def apply(instance)
    if valid(instance)
      instance.define_singleton_method self.name, self.implementation
    end
  end
end

class Validation
  include Action

  def initialize(condition)
    self.condition = condition
  end

  def apply(instance)
    raise ValidationError unless valid(instance)
  end

end

#Class Exec dsl
class ClassExecutionContext
  attr_accessor :klass

  def initialize klass
    self.klass = klass
  end

  def add_attributes(*sym)
    self.klass.class_eval do
      attr_accessor *sym
    end
  end

  def add_method(signature, &block)
    self.klass.send :define_method, signature, block
  end

  def include_module(module_name)
    self.klass.class_eval do
      include module_name
    end
  end
end

#Exceptions
class BuildError < StandardError
end


class ValidationError < BuildError
end

