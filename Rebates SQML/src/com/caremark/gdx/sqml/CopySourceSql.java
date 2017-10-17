package com.caremark.gdx.sqml;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;

/**
 * @author Bryan Castillo
 *
 */
public class CopySourceSql extends AbstractXMLCopySource {

	private final static org.apache.log4j.Logger logger = org.apache.log4j.Logger
			.getLogger(CopySourceSql.class.getName());
	
	private boolean substitueParameters = true;
	private boolean interpretSql = true;
	
	private PreparedStatement ps;
	private ResultSet rs;

	/**
	 * @throws SqlXmlException
	 * @throws SQLException
	 * @see com.caremark.gdx.sqml.ICopySource#start(com.caremark.gdx.sqml.CommandCopy)
	 */
	public void start() throws SqlXmlException, SQLException {
		String sql;
		ResultSetMetaData rsmd;
		int ncols;
		String[] columns;
		int[] columnTypes;
		Connection c = null;
		
		sql = getContent();
		if (interpretSql) {
			sql = getScript().expandProperties(sql);
		}
		c = getConnection();
		logger.info("start: preparing sql:\n" + sql);
		ps = getScript().prepare(c, sql, substitueParameters);
		rs = ps.executeQuery();
		rsmd = rs.getMetaData();
		ncols = rsmd.getColumnCount();
		
		// Get the column names
		columns = new String[ncols];
		columnTypes = new int[ncols];
		for (int i=0; i<ncols; i++) {
			columns[i] = rsmd.getColumnName(i+1);
			columnTypes[i] = rsmd.getColumnType(i+1);
		}
		setColumnLabels(columns);
		setColumnTypes(columnTypes);
	}

	/**
	 * @throws SqlXmlException
	 * @throws SQLException
	 * @see com.caremark.gdx.sqml.ICopySource#finish(com.caremark.gdx.sqml.CommandCopy)
	 */
	public void finish() throws SqlXmlException, SQLException {
		if (rs != null) {
			try {
				rs.close();
			}
			catch (SQLException sqle) {
				logger.error("finish: " + sqle.getMessage(), sqle);
			}
			rs = null;
		}
		if (ps != null) {
			try {
				ps.close();
			}
			catch (SQLException sqle) {
				logger.error("finish: " + sqle.getMessage(), sqle);
			}
			ps = null;
		}
		super.finish();
	}

	/**
	 * @return
	 * @throws SqlXmlException
	 * @throws SQLException
	 * @see com.caremark.gdx.sqml.ICopySource#getRow(com.caremark.gdx.sqml.CommandCopy)
	 */
	public Object[] getRow() throws SqlXmlException,
			SQLException
	{
		Object[] row;
		if (!rs.next()) {
			return null;
		}
		row = new Object[getColumnLabels().length];
		for (int i=0; i<row.length; i++) {
			row[i] = rs.getObject(i+1);
		}
		return row;
	}

	/**
	 * @return Returns the interpretSql.
	 */
	public boolean isInterpretSql() {
		return interpretSql;
	}
	/**
	 * @param interpretSql The interpretSql to set.
	 */
	public void setInterpretSql(boolean interpretSql) {
		this.interpretSql = interpretSql;
	}
	/**
	 * @return Returns the substitueParameters.
	 */
	public boolean isSubstitueParameters() {
		return substitueParameters;
	}
	/**
	 * @param substitueParameters The substitueParameters to set.
	 */
	public void setSubstitueParameters(boolean substitueParameters) {
		this.substitueParameters = substitueParameters;
	}
}
