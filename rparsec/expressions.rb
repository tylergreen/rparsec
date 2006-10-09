require 'rparsec/parser'

Associativities = [:prefix, :postfix, :infixn, :infixr, :infixl]
#
# This class holds information about operator precedences
# and associativities.
# prefix, postfix, infixl, infixr, infixn can be called
# to register operators.
# 
class OperatorTable
  attr_reader :operators
  #
  # Re-initialize the operator table.
  #
  def reinit
    @operators = []
  end
  #
  # To create an OperatorTable instance.
  # If a block is given, it is invoked to do post-instantiation.
  # For example:
  # 
  # OperatorTable.new do |tbl|
  #   tbl.infixl(char(?+) >> Plus)
  #   tbl.infixl(char(?-) >> Minus)
  #   tbl.prefix(char(?-) >> Neg)
  # end
  #
  def self.new
    this = allocate
    this.reinit
    if block_given?
      yield this
    end
    this
  end
  private
  #
  # To define methods for registering operator. 
  # This is typically used internally. 
  #
  def self.def_operator(*kinds)
    kinds.each do |kind|
      define_method(kind) do |op, precedence|
        add(kind, op, precedence)
      end
    end
  end
  def_operator(*Associativities)
  def add(*entry)
    @operators << entry
    self
  end
end

#
# This module helps build an expression parser
# using an OperatorTable instance and a parser
# that parses the term expression.
#  
module Expressions
  private
  def self.array_to_dict arr
    result = {}
    arr.each_with_index do |key,i|
      result [key] = i unless result.include? key
    end
    result
  end
  KindPrecedence = array_to_dict Associativities
  public
  #
  # build an expression parser using the given term parser
  # and operator table.
  # When _delim_ is specified, patterns recognized by _delim_
  # is automatically ignored.
  #
  def self.build(term, table, delim=nil)
    # sort so that higher precedence first.
    apply_operators(term, prepare_suites(table).sort, delim)
  end
  private
  def self.apply_operators(term, entries, delim)
  # apply operators stored in [[precedence,associativity],[op...]] starting from beginning.
    entries.inject(term) do |result, entry|
      key, ops = *entry
      null, kind_index = *key
      op = ops[0]
      op = Parsers.sum(*ops) if ops.length>1
      apply_operator(result, op, Associativities[kind_index], delim)
    end
  end
  def self.apply_operator(term, op, kind, delim)
    term, op = ignore_rest(term, delim), ignore_rest(op, delim)
    # we could use send here, 
    # but explicit case stmt is more straight forward and less coupled with names.
    # performance might be another benefit,
    # though it is not clear whether meta-code is indeed slower than regular ones at all.
    case kind
      when :prefix
        term.prefix(op)
      when :postfix
        term.postfix(op)
      when :infixl
        term.infixl(op)
      when :infixr
        term.infixr(op)
      when :infixn
        term.infixn(op)
      else
        raise ArgumentError, "unknown associativity: #{kind}"
    end
  end
  def self.ignore_rest(parser, delim)
    return parser if delim.nil?
    parser << delim
  end
  def self.prepare_suites(table)
  # create a hash with [precedence, associativity] as key, and op as value.
    suites = {}
    table.operators.each do |entry|
      kind, op, precedence = *entry
      key = [-precedence, KindPrecedence[kind]]
      suite = suites[key]
      if suite.nil?
        suite = [op]
        suites[key] = suite
      else
        suite << op
      end
    end
    suites
  end
end