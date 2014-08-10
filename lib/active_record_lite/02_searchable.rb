require_relative 'db_connection'
require_relative '01_sql_object'

module Searchable
  def where(params)
    where_line = params.keys.map { |key| "#{key.to_s} = ?" }.join(' AND ')
    query = <<-SQL
      SELECT *
      FROM #{self.table_name}
      WHERE #{where_line}
    SQL
    self.parse_all(DBConnection.execute(query, *params.values))
  end
end

class SQLObject
  extend Searchable
end
