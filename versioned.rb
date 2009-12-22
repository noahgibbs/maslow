module Versioned

  class Version
    def initialize(parent)
      @parent = parent
      @parent.ref if @parent
      @children = []
      @refs = 1
    end

    def parent
      @parent
    end

    def children
      @children
    end

    def ref
      @refs += 1
    end

    def unref
      @refs -= 1
      @parent.delete_child_version(self) if @refs == 0
    end

    def new_child_version
      child = Version.new self
      @children << child
      child
    end

    def delete_child_version(child)
      @children -= [ child ]
      child.unref
      nil
    end
  end

  class Root
    def initialize
      @version = Version.new nil
    end

    def version
      @version
    end

    def new_version
      newver = @version.new_child_version
      @version = newver
      @version
    end

    def rollback(to = nil)
      unless to
        to = @version.parent
      end

      raise "Can't roll back from base state!" unless to

      to_unref = [ @version ]
      index = @version.parent
      while index && index != to
        to_unref << index
        index = index.parent
      end

      @version = to
      to_unref.each {|ver| ver.unref}
    end

  end

end

def convert_to_versioned(new_root, item)
  return item if item.is_a? Versioned::Hash

  if item.is_a? ::Hash
    hash = Versioned::Hash.new new_root
    item.each_pair { |key, val|
      hash[key] = convert_to_versioned(new_root, val)
    }
    hash
  elsif item.is_a? Array
    item.map { |elt| convert_to_versioned(new_root, elt) }
  else
    item
  end
end

class Versioned::Hash
  def initialize(root, hash = {})
    @root = root
    @values = {}
    @values[@root.version] = hash
  end

  def root=(newroot)
    raise "Root is already set!" if @root && @root != newroot
    @root = newroot
  end

  def root
    @root
  end

  define_method "[]".to_sym, proc { |key|
    ver = @root.version
    begin
      if @values[ver]
        return @values[ver][key] if @values[ver].has_key?(key)
      end
      ver = ver.parent
      return nil unless ver
    end while true
  }

  define_method "[]=".to_sym, proc { |key, value|
    value = convert_to_versioned(@root, value)
    @values[@root.version] ||= {}
    @values[@root.version][key] = value
  }

  def keys
    self.collapse.keys
  end

  def values
    self.collapse.values
  end

  def each_pair(&block)
    self.collapse.each_pair &block
  end

  define_method "==".to_sym, proc { |value|
    if value.is_a? Versioned::Hash
      value = value.collapse
    end

    self.collapse == value
  }

  # Later we can cache this
  def collapse(version = @root.version)
    par = version.parent
    return @values[version] unless par
    prev = collapse par
    prev.merge @values[version]
  end

end
