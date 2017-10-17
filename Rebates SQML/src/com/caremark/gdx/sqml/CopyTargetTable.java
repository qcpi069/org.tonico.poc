package com.caremark.gdx.sqml;

import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.ResultSet;
import java.sql.SQLException;

/**
 * @author Bryan Castillo
 *
 */
public class CopyTargetTable extends CopyTargetSql {

	private final static org.apache.log4j.Logger logger = org.apache.log4j.Logger
			.getLogger(CopyTargetTable.class.getName());
	
	private String table;
	private String catalog = null;
	private String schema = null;
	private String sql;
	
	public String getSql() throws SqlXmlException, SQLException {
		if (sql == null) {
			Connection c = null;
			DatabaseMetaData dmd;
			ResultSet rs = null;
			StringBuffer _sql = new StringBuffer();
			int count = 0;
			try {
				c = getConnection();
				logger.debug("getSql: getting meta data");
				dmd = c.getMetaData();
				rs = dmd.getColumns(catalog, schema, getTable(), null);
				logger.debug("getSql: done getting meta data");
				_sql.append("INSERT INTO ").append(getTable()).append(" VALUES (");
				while (rs.next()) {
					if (count > 0) {
						_sql.append(',');
					}
					_sql.append('?');
					count++;
				}
				_sql.append(')');
				if (count == 0) {
					throw new SqlXmlException("Couldn't create insert statement for table " + getTable());
				}
				sql = _sql.toString();
			}
			finally {
				if (rs != null) {
					try {
						rs.close();
					}
					catch (SQLException sqle) {
						logger.error("start: " + sqle.getMessage(), sqle);
					}
				}
			}
		}
		return sql;
	}

	/**
	 * @return Returns the table.
	 */
	public String getTable() {
		return table;
	}
	/**
	 * @param table The table to set.
	 */
	public void setTable(String table) {
		this.table = table;
	}

	public String getCatalog() {
		return catalog;
	}

	public void setCatalog(String catalog) {
		this.catalog = catalog;
	}

	public String getSchema() {
		return schema;
	}

	public void setSchema(String schema) {
		this.schema = schema;
	}
}
