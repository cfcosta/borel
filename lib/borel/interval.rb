require 'borel/errors'

Infinity = 1/0.0

class Interval
  include Enumerable

  def Interval.[](*array)
    union(*
      if array.empty?
        []
      elsif array.first.kind_of?(Array)
        array.select{|x| !x.empty?}.map{|x| Simple.new(*x)}
      else
        [Simple.new(*array)]
      end
    )
  rescue
    unless
        array.size <= 2 || array.all?{|x| Array === x && x.size <= 2}
      raise Exception::Construction, array
    end
    raise
  end

  def Interval.union(*array)
    l = []
    array.map(&:components).flatten.sort_by(&:inf).each{|x|
      if x.sup < x.inf
        # skip it
      elsif l.empty? || x.inf > l.last.sup
        l <<= x
      elsif x.sup > l.last.sup
        l[-1] = Simple.new(l.last.inf, x.sup)
      end
    }
    if l.size == 1
      l.first
    else
      Multiple.new(l)
    end
  end

  def construction
    map{|x| x.extrema.uniq}
  end

  def simple?
    false
  end

  def inspect
    "Interval" + construction.inspect
  end

  def to_s
    inspect
  end

  def ==(other)
    self.components == other.components
  end

  def include?(x)
    any?{|i| i.include? x}
  end

  def to_interval
    self
  end

  def coerce(other)
    [other.to_interval, self]
  end

  def empty?
    components.empty?
  end

  def degenerate?
    all? {|x| x.degenerate?}
  end

  def hull
    if empty?
      Interval[]
    else
      Interval[components.first.inf, components.last.sup]
    end
  end

  def union(other)
    Interval.union(other.to_interval, self)
  end

  def +(other)
    self | other
  end

  def ^(other)
    self & other
  end

  def |(other)
    self.union other.to_interval
  end

  [[:&, :intersect]].each do |op, meth|
    define_method(op) {|other|
      (other.to_interval.map{|y| map{|x| x.send(meth,y)}}.flatten).reduce(:|) || Interval[]
    }
  end

  [[:~, :complement]].each do |op, meth|
    define_method(op) {
      map{|x| x.to_interval.map(&meth).reduce(:&)}.flatten.reduce(:|)
    }
  end

  [[:-, :minus]].each do |op, meth|
    define_method(op) {|other|
      if other.empty?
        self
      else
        map{|x| other.to_interval.map{|y| x.send(meth,y)}.reduce(:&)}.flatten.reduce(:|) || Interval[]
      end
    }
  end
end

class Interval::Simple < Interval
  include Enumerable

  attr :inf
  attr :sup

  def each
    yield(self)
    self
  end

  def components
    [self]
  end

  def initialize (a, b = a)
    if (a.respond_to?(:nan?) && a.nan? ) || (b.respond_to?(:nan?) && b.nan?)
      @inf, @sup = -Infinity, Infinity
    else
      @inf, @sup = a, b
    end
    freeze
  end

  def ==(other)
    [inf, sup] == [other.inf, other.sup]
  end

  def intersect(other)
    Interval[[inf, other.inf].max, [sup, other.sup].min]
  end

  def complement
    Interval[-Infinity,inf] | Interval[sup,Infinity]
  end

  def minus (other)
    self & ~other
  end

  def construction
    extrema.uniq
  end

  def simple?
    true
  end

  def include?(x)
    inf <= x  && x <= sup
  end

  def extrema
    [inf, sup]
  end

  def degenerate?
    inf == sup
  end
end

class Interval::Multiple < Interval
  attr :components

  def initialize(array)
    @components = array
    freeze
  end

  def each
    components.each{|o| yield(o)}
    self
  end
end
