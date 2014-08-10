require_relative 'db_connection'
require 'active_support/inflector'
#NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
#    of this project. It was only a warm up.

class SQLObject
  def self.columns
    data_array = DBConnection.execute2("SELECT * FROM #{self.table_name}")
    data_array.first.each do |col_name|
      define_method(col_name) do
        attributes[col_name.to_sym]
      end
      define_method("#{col_name}=") do |val|
        attributes[col_name.to_sym] = val
      end
    end
    data_array.first.map(&:to_sym)
  end

  def self.table_name=(table_name)
    instance_variable_set "@table_name", table_name
  end

  def self.table_name
    var = instance_variable_get "@table_name"
    var || "#{self}".tableize
  end

  def self.all
    query = <<-SQL
      SELECT #{self.table_name}.*
      FROM #{self.table_name}
    SQL
    self.parse_all(DBConnection.execute(query))
  end
  
  def self.parse_all(results)
    output = []
    results.each do |hash|
      new_hash = Hash.new
      hash.each { |key, value| new_hash[key.to_sym] = value }
      output << self.new(new_hash)
    end
    output
  end

  def self.find(id)
    query = <<-SQL
      SELECT #{self.table_name}.*
      FROM #{self.table_name}
      WHERE id = ?
    SQL
    self.parse_all(DBConnection.execute(query, id)).first
  end

  def attributes
    attr_hash = instance_variable_get "@attributes"
    attr_hash || instance_variable_set("@attributes", Hash.new)
  end

  def insert
    col_names = self.class.columns.join(', ')
    question_marks = (["?"] * self.class.columns.length).join(', ')
    query = <<-SQL
      INSERT INTO #{self.class.table_name} (#{col_names})
      VALUES (#{question_marks})
    SQL
    DBConnection.execute(query, *attribute_values)
    self.id = DBConnection.last_insert_row_id
  end

  def initialize(params = nil)
    unless params.nil?
      params.each do |key, value|
        raise "unknown attribute '#{key}'" unless self.class.columns.include?(key.to_sym)
      end
    end
    @attributes = params
  end

  def save
    self.id.nil? ? self.insert : self.update
  end
  
  def update
    set_line = self.class.columns.map { |col| "#{col} = ?" }.join(', ')
    query = <<-SQL
      UPDATE #{self.class.table_name}
      SET #{set_line}
      WHERE id = ?
    SQL
    DBConnection.execute(query, *attribute_values, self.id)
  end

  def attribute_values
    self.class.columns.map { |column| attributes[column] }
  end
end
