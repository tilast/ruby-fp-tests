class MyLambda
  def initialize &block
    @block = block
  end

  def call(*args)
    raise(
      ArgumentError,
      "Wrong number of arguments passed to lambda: expected #{@block.arity}, got #{args.length}"
    ) if args.length != @block.arity && @block.arity > 0

    @block.(*args)
  end
end

def kinda(&block)
  MyLambda.new &block
end

# (MyLambda.new { |a, *b, c| p(a, b, c) }).(10, 12)
# kinda { |a, *b, c| p(a, b, c) }.(10, 12)

class Maybe
  def initialize(value)
    @value = value
  end

  def nothing?
    @value.nil?
  end

  def just?
    !nothing?
  end

  def value
    if just?
      @value
    else
      raise "Can't get something from nothing"
    end
  end

  def ==(other)
    return value == other.value if just? && other.just?

    nothing? && other.nothing?
  end

  def and_then(f)
    f.(self)
  end
end

def Just(x)
  raise "Can't make something from nothing" if x.nil?

  Maybe.new(x)
end

def Nothing(*_)
  Maybe.new(nil)
end

class Currying
  def initialize(f, *args)
    @f = f
    @args = args
  end

  def call(*args)
    @f.(*(@args + args))
  end
end

def curry(f, *args)
  Currying.new(f, *args)
end

max = kinda { |x, y| x >= y ? x : y }
(curry(max, 4)).(5)


class Composition
  def initialize(f, g)
    @f = f
    @g = g
  end

  def call(x)
    @f.( @g.( x ) )
  end
end

def compose(f, g)
  Composition.new(f, g)
end

get_len = kinda { |x| x.length }
add_foo = kinda { |x| x + '_foo' }

# fmap = kinda do |f, x|
#   if x.just?
#     Just(f.(x.value))
#   else
#     Nothing()
#   end
# end

def fmap(f, x)
  if x.just?
    Just(f.(x.value))
  else
    Nothing()
  end
end

def liftA(mf, ma)
  if mf.just?
    fmap(mf.value, ma)
  else
    ma
  end
end

# doubleNum = Just(kinda { |num| num * 2 })
# doubleNumNil = Nothing()
#
# p liftA.(doubleNum, Just(10)) == Just(20)
# p liftA.(doubleNum, Nothing()) == Nothing()
# p liftA.(doubleNumNil, Just(10)) == Just(10)
# p liftA.(doubleNumNil, Nothing()) == Nothing()

def liftM(ma, f)
  if ma.just?
    f.(ma.value)
  else
    Nothing()
  end
end

# doubleNum = kinda { |num| Just(num * 2) }
# doubleNumNil = kinda { |_| Nothing() }
#
# p liftM.(Just(10), doubleNum) == Just(20)
# p liftM.(Nothing(), doubleNum) == Nothing()
# p liftM.(Nothing(), doubleNumNil) == Nothing()
# p liftM.(Just(10), doubleNumNil) == Nothing()

# p fmap.(kinda { |value| value * 10 }, Just(123))
# p fmap.(kinda { |value| value * 10 }, Nothing())

# 1. identity operation behaves the same when it's mapped
id = kinda { |x| x }
fmap_id = curry(method(:fmap), id)
#
# fmap_id.(Nothing())   == id.(Nothing())   # => true
# fmap_id.(Just("foo")) == id.(Just("foo")) # => true
#
# # 2. composition of fmaps should equal fmap of composition
# g = ->(s) { s + "_bar" }
# f = ->(s) { s.length }
#
# f_fmapped = curry(fmap, f)
# g_fmapped = curry(fmap, g)
# f_fmapped_g_fmapped = compose(f_fmapped, g_fmapped)
#
# f_g_fmapped = curry(fmap, compose(f, g))
#
# p (f_fmapped_g_fmapped.(Just('canicu')) == f_g_fmapped.(Just('canicu')))
# p(f_fmapped_g_fmapped.(Nothing()) == f_g_fmapped.(Nothing()))
#

# fmap = kinda do |f, x|
#   if x.just?
#     Just(f.(x.value))
#   else
#     Nothing()
#   end
# end
#
# liftA = kinda do |mf, ma|
#   if mf.just?
#     fmap.(mf.value, ma)
#   else
#     ma
#   end
# end
#
# liftM = kinda do |ma, f|
#   if ma.just?
#     f.(ma.value)
#   else
#     Nothing()
#   end
# end

class Many
  attr_reader :value

  def initialize(*args)
    @value = Array(*args).flat_map { |e| e.class == Maybe ? e : (e.nil? ? Nothing() : Just(e)) }
  end

  def map(f)
    Many.new(@value.map { |e| liftM(e, f) })
  end

  def filter(f)
    Many.new(@value.select { |e| liftM(e, f).value == true })
  end

  def reduce(f, init)
    @value.reduce(init) { |acc, e| f.(acc, e) }
  end

  def concat(list)
    Many.new(@value + list.value)
  end

  def empty?
    @value.empty?
  end

  def push(e)
    @value << (e.class == Maybe ? e : (e.nil? ? Nothing() : Just(e)))
  end

  def raw_value
    @value.map { |m| m.value }
  end

  # def reduce(f)
  #   Many.new(@value.select { |e| fmap.(f, e).value == true })
  # end
end

def quicksort(list)
  head, *tail = list.value

  return Many.new([]) if head.nil?
  mny = Many.new(tail)

  quicksort(mny.filter(kinda { |x| x <= head.value ? Just(true) : Just(false) }))
    .concat(Many.new(head))
    .concat(quicksort(mny.filter(kinda { |x| x > head.value ? Just(true) : Just(false) })))
end

arr = Many.new([5,4,3,2,1])

p quicksort(arr).raw_value

def length(list)
  _length = 0
  len(list, _length)
end

def len(list, l)
  head, *tail = list.value

  return l if head.nil?

  len(Many.new(tail), l + 1)
end

def element_at(list, position)
  head, *tail = list.value

  return Nothing() if head.nil?
  return head if position == 0

  element_at(Many.new(tail), position - 1)
end

def split_by(list, num)
  split_by_routine(list, num, Many.new([]))
end

def split_by_routine(list, num, left)
  head, *tail = list.value

  return [Many.new([head]), Many.new(tail)] if num == 0 && !head.nil?
  return [left, Many.new(tail)] if num == 0 || head.nil?

  split_by_routine(list, num - 1, Many.new(left.value + [head]))
end

def binary_routine(list, e)
  head, *tail = list.value

  if e == head
    return true
  end

  if tail.empty?
    return false
  end

  center = length(list) / 2
  left, right = split_by(list, center)

  element_at(list, center).value > e.value ? binary_routine(right, e) : binary_routine(left, e)
end

def binary_search(list, e)
  return Nothing() if e == Nothing()
  binary_routine(quicksort(list), e)
end

p binary_search(Many.new([1,2,3,4]), Just(2))
